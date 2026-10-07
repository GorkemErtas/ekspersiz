from dataclasses import dataclass
from enum import Enum
import re


class AssistantIntent(str, Enum):
    VEHICLE_GENERAL = "VEHICLE_GENERAL"
    INSPECTION = "INSPECTION"
    MAINTENANCE = "MAINTENANCE"
    DRIVING_USAGE = "DRIVING_USAGE"
    SAFETY = "SAFETY"
    VEHICLE_SPEC = "VEHICLE_SPEC"
    USER_VEHICLE = "USER_VEHICLE"
    DAMAGE_HISTORY = "DAMAGE_HISTORY"
    REMINDER = "REMINDER"
    APP_HELP = "APP_HELP"
    OUT_OF_SCOPE = "OUT_OF_SCOPE"


@dataclass(frozen=True)
class RouteDecision:
    intent: AssistantIntent
    in_scope: bool
    use_rag: bool = False
    knowledge_source: str = "PUBLIC_WEB"
    tool_name: str | None = None
    reason: str = ""
    automotive_relevance: float = 0.0
    assistant_capability: float = 0.0
    vehicle_year: int | None = None
    vehicle_make: str | None = None
    vehicle_model: str | None = None
    vehicle_trim: str | None = None
    vehicle_market: str | None = None
    clarification_needed: bool = False
    clarification_message: str | None = None


class DeterministicDomainRouter:
    """Cheap first-pass guard. It intentionally prefers refusal over guessing."""

    _patterns = {
        AssistantIntent.DAMAGE_HISTORY: (r"hasar", r"damage", r"analizim", r"ekspertiz"),
        AssistantIntent.REMINDER: (r"hatırlat", r"muayeneme.*kald", r"bakıma.*kald", r"reminder"),
        AssistantIntent.INSPECTION: (r"muayene", r"tüvtürk", r"kusur"),
        AssistantIntent.MAINTENANCE: (r"bakım", r"lastik", r"motor yağı", r"fren", r"akü", r"filtre", r"triger"),
        AssistantIntent.SAFETY: (r"uyarı lamb", r"airbag", r"abs", r"hararet", r"yağ basın", r"güvenli"),
        AssistantIntent.DRIVING_USAGE: (r"park freni", r"el freni", r"vites", r"şanzıman", r"nasıl sür"),
        AssistantIntent.APP_HELP: (r"ekspersiz", r"uygulama", r"kredi", r"ai asistan"),
    }
    _vehicle_terms = re.compile(r"\b(arabam|aracım|araba|araç|otomobil|motor|vehicle|car)\b", re.I)
    _personal_terms = re.compile(r"\b(aracım|arabam|benim|bende|kaydım|son analizim)\b", re.I)
    _spec_terms = re.compile(r"\b(kaç airbag|beygir|hp|motor hacmi|donanım|paket|trim|lastik ölç|yakıt deposu)\b", re.I)

    def route(self, question: str) -> RouteDecision:
        text = " ".join(question.lower().split())
        if not text:
            return RouteDecision(AssistantIntent.OUT_OF_SCOPE, False, reason="empty")

        if self._personal_terms.search(text):
            if any(re.search(p, text) for p in self._patterns[AssistantIntent.DAMAGE_HISTORY]):
                return RouteDecision(AssistantIntent.DAMAGE_HISTORY, True, tool_name="getDamageHistory", reason="personal damage history")
            if any(re.search(p, text) for p in self._patterns[AssistantIntent.REMINDER]):
                return RouteDecision(AssistantIntent.REMINDER, True, tool_name="getUpcomingReminders", reason="personal reminder")
            return RouteDecision(AssistantIntent.USER_VEHICLE, True, tool_name="getMyVehicles", reason="personal vehicle")

        if self._spec_terms.search(text):
            return RouteDecision(AssistantIntent.VEHICLE_SPEC, True, use_rag=True, reason="vehicle specification")

        for intent in (AssistantIntent.INSPECTION, AssistantIntent.MAINTENANCE,
                       AssistantIntent.SAFETY, AssistantIntent.DRIVING_USAGE,
                       AssistantIntent.APP_HELP):
            if any(re.search(p, text) for p in self._patterns[intent]):
                return RouteDecision(intent, True, use_rag=True, reason="domain keyword")

        if self._vehicle_terms.search(text):
            return RouteDecision(AssistantIntent.VEHICLE_GENERAL, True, use_rag=True, reason="general vehicle question")

        return RouteDecision(AssistantIntent.OUT_OF_SCOPE, False, reason="no automotive signal")
