import unittest
from unittest.mock import Mock
from app.assistant.orchestrator import AssistantOrchestrator
from app.assistant.routing import AssistantIntent, DeterministicDomainRouter


class AssistantRoutingTest(unittest.TestCase):
    def setUp(self):
        self.router = DeterministicDomainRouter()

    def test_rejects_unrelated_question_without_rag(self):
        retriever = Mock()
        plan = AssistantOrchestrator(self.router, retriever).plan("Bana Python ile web scraper yaz")
        self.assertEqual(AssistantIntent.OUT_OF_SCOPE, plan.decision.intent)
        self.assertFalse(plan.decision.in_scope)
        retriever.retrieve.assert_not_called()

    def test_routes_general_inspection_question_to_rag(self):
        decision = self.router.route("Muayeneye gitmeden önce neleri kontrol etmeliyim?")
        self.assertEqual(AssistantIntent.INSPECTION, decision.intent)
        self.assertTrue(decision.use_rag)

    def test_routes_personal_damage_question_to_secure_tool(self):
        decision = self.router.route("Aracımın son hasar analizinde ne çıktı?")
        self.assertEqual(AssistantIntent.DAMAGE_HISTORY, decision.intent)
        self.assertEqual("getDamageHistory", decision.tool_name)
        self.assertFalse(decision.use_rag)

    def test_routes_personal_reminder_question(self):
        decision = self.router.route("Aracımın muayenesine kaç gün kaldı?")
        self.assertEqual(AssistantIntent.REMINDER, decision.intent)
        self.assertEqual("getUpcomingReminders", decision.tool_name)

    def test_vehicle_spec_requires_evidence_path(self):
        decision = self.router.route("2020 Corolla kaç airbag var?")
        self.assertEqual(AssistantIntent.VEHICLE_SPEC, decision.intent)
        self.assertTrue(decision.use_rag)


if __name__ == "__main__":
    unittest.main()
