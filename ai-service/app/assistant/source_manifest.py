import json
from dataclasses import dataclass
from pathlib import Path

from .ingestion import KnowledgeSource


@dataclass(frozen=True)
class KnowledgeManifest:
    sources: list[KnowledgeSource]

    @classmethod
    def load(cls, knowledge_root: Path, manifest_path: Path,
             source_version: str) -> "KnowledgeManifest":
        data = json.loads(manifest_path.read_text(encoding="utf-8"))
        defaults = data.get("defaults", {})
        resolved: list[KnowledgeSource] = []
        seen: set[Path] = set()

        for rule in data.get("sources", []):
            for path in sorted(knowledge_root.glob(rule["glob"])):
                if not path.is_file() or path in seen:
                    continue
                seen.add(path)
                resolved.append(KnowledgeSource(
                    path=path,
                    category=rule["category"],
                    source_name=rule.get("source_name", defaults.get("source_name", "Unknown")),
                    source_version=rule.get("source_version", source_version),
                    source_url=rule.get("source_url"),
                    authority=rule.get("authority", defaults.get("authority", "CURATED")),
                    language=rule.get("language", defaults.get("language", "tr")),
                    market=rule.get("market", defaults.get("market")),
                ))
        return cls(resolved)
