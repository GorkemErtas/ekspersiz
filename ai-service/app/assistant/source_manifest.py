import json
import re
from dataclasses import dataclass
from datetime import date
from pathlib import Path

from .ingestion import KnowledgeSource

_ID_RE = re.compile(r"^[a-z0-9][a-z0-9-]{2,79}$")
_ALLOWED_AUTHORITIES = {"OFFICIAL", "VERIFIED", "CURATED"}
_ALLOWED_CATEGORIES = {"VEHICLE_GENERAL", "INSPECTION", "MAINTENANCE", "DRIVING_USAGE", "SAFETY", "VEHICLE_SPEC", "APP_HELP"}
_LANGUAGE_RE = re.compile(r"^[a-z]{2,3}(?:-[A-Z]{2})?$")
_MARKET_RE = re.compile(r"^[A-Z]{2,3}$")
_VERSION_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$")


def _date(value: str | None) -> date | None:
    return date.fromisoformat(value) if value else None


@dataclass(frozen=True)
class KnowledgeManifest:
    sources: list[KnowledgeSource]

    @classmethod
    def load(cls, knowledge_root: Path, manifest_path: Path,
             source_version: str) -> "KnowledgeManifest":
        data = json.loads(manifest_path.read_text(encoding="utf-8"))
        defaults = data.get("defaults", {})
        rules = data.get("sources")
        if not isinstance(rules, list):
            raise ValueError("knowledge manifest sources must be a list")

        resolved: list[KnowledgeSource] = []
        seen_paths: set[Path] = set()
        seen_ids: set[str] = set()

        for rule in rules:
            enabled = rule.get("enabled", True)
            if not isinstance(enabled, bool):
                raise ValueError("knowledge source enabled must be a boolean")
            if not enabled:
                continue
            if not rule.get("glob") or not rule.get("category"):
                raise ValueError("each knowledge source rule requires glob and category")

            category = rule["category"]
            if category not in _ALLOWED_CATEGORIES:
                raise ValueError(f"invalid knowledge category: {category}")

            language = rule.get("language", defaults.get("language", "tr"))
            market = rule.get("market", defaults.get("market"))
            version = rule.get("source_version", source_version)
            if not isinstance(language, str) or not _LANGUAGE_RE.fullmatch(language):
                raise ValueError(f"invalid knowledge language: {language}")
            if market is not None and (not isinstance(market, str) or not _MARKET_RE.fullmatch(market)):
                raise ValueError(f"invalid knowledge market: {market}")
            if not isinstance(version, str) or not _VERSION_RE.fullmatch(version):
                raise ValueError(f"invalid knowledge source_version: {version}")

            explicit_id = rule.get("id")
            if explicit_id and not _ID_RE.fullmatch(explicit_id):
                raise ValueError(f"invalid knowledge source id: {explicit_id}")

            authority = rule.get("authority", defaults.get("authority", "CURATED"))
            if authority not in _ALLOWED_AUTHORITIES:
                raise ValueError(f"invalid knowledge authority: {authority}")

            vehicle_years = tuple(rule.get("vehicle_years", ()))
            vehicle_models = tuple(rule.get("vehicle_models", ()))
            vehicle_trims = tuple(rule.get("vehicle_trims", ()))
            if any(not isinstance(year, int) or year < 1886 or year > 2100 for year in vehicle_years):
                raise ValueError("vehicle_years must contain valid integer years")
            if any(not isinstance(value, str) or not value.strip() for value in (*vehicle_models, *vehicle_trims)):
                raise ValueError("vehicle_models and vehicle_trims must contain non-empty strings")
            if category == "VEHICLE_SPEC" and (not vehicle_years or not vehicle_models):
                raise ValueError("VEHICLE_SPEC sources require vehicle_years and vehicle_models")

            valid_from = _date(rule.get("valid_from"))
            valid_until = _date(rule.get("valid_until"))
            if valid_from and valid_until and valid_until < valid_from:
                raise ValueError("knowledge valid_until cannot be before valid_from")

            matches = [p for p in sorted(knowledge_root.glob(rule["glob"])) if p.is_file()]
            if explicit_id and not matches:
                raise ValueError(f"knowledge source id {explicit_id} did not match a file")
            if explicit_id and len(matches) > 1:
                raise ValueError(
                    f"knowledge source id {explicit_id} must resolve to exactly one file"
                )

            for path in matches:
                if path in seen_paths:
                    raise ValueError(f"knowledge source file matched by multiple rules: {path}")
                seen_paths.add(path)
                slug = explicit_id
                if slug:
                    if slug in seen_ids:
                        raise ValueError(f"duplicate knowledge source id: {slug}")
                    seen_ids.add(slug)

                resolved.append(KnowledgeSource(
                    path=path,
                    category=category,
                    source_name=rule.get(
                        "source_name", defaults.get("source_name", "Unknown")),
                    source_version=version,
                    slug=slug,
                    source_url=rule.get("source_url"),
                    authority=authority,
                    language=language,
                    market=market,
                    valid_from=valid_from,
                    valid_until=valid_until,
                    vehicle_years=vehicle_years,
                    vehicle_models=vehicle_models,
                    vehicle_trims=vehicle_trims,
                ))
        return cls(resolved)
