import unittest
from unittest.mock import Mock

from app.assistant.orchestrator import AssistantOrchestrator
from app.assistant.routing import AssistantIntent, RouteDecision


class AssistantRoutingTest(unittest.TestCase):
    def test_out_of_scope_decision_never_calls_retriever(self):
        router = Mock()
        router.route.return_value = RouteDecision(
            intent=AssistantIntent.OUT_OF_SCOPE,
            in_scope=False,
            use_rag=False,
            tool_name=None,
            reason="semantic rejection",
            automotive_relevance=0.05,
            assistant_capability=0.02,
        )
        retriever = Mock()

        plan = AssistantOrchestrator(router, retriever).plan(
            "Bana Python ile web scraper yaz"
        )

        self.assertEqual(AssistantIntent.OUT_OF_SCOPE, plan.decision.intent)
        self.assertFalse(plan.decision.in_scope)
        retriever.retrieve.assert_not_called()

    def test_semantic_rag_decision_retrieves_context(self):
        router = Mock()
        router.route.return_value = RouteDecision(
            intent=AssistantIntent.INSPECTION,
            in_scope=True,
            use_rag=True,
            tool_name=None,
            reason="inspection guidance",
            automotive_relevance=0.96,
            assistant_capability=0.91,
        )
        retriever = Mock()
        retriever.retrieve.return_value = ["chunk"]

        plan = AssistantOrchestrator(router, retriever).plan(
            "Muayene öncesinde nelere dikkat etmeliyim?"
        )

        self.assertEqual(["chunk"], plan.context)
        retriever.retrieve.assert_called_once()

    def test_secure_tool_decision_does_not_require_rag(self):
        router = Mock()
        router.route.return_value = RouteDecision(
            intent=AssistantIntent.DAMAGE_HISTORY,
            in_scope=True,
            use_rag=False,
            tool_name="getDamageHistory",
            reason="authorized user data",
            automotive_relevance=0.98,
            assistant_capability=0.95,
        )
        retriever = Mock()

        plan = AssistantOrchestrator(router, retriever).plan(
            "Son hasar analizimde ne çıktı?"
        )

        self.assertEqual("getDamageHistory", plan.decision.tool_name)
        retriever.retrieve.assert_not_called()


if __name__ == "__main__":
    unittest.main()
