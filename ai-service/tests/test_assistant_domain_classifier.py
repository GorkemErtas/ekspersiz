import json
import unittest
from unittest.mock import patch

from app.assistant.domain_classifier import SemanticDomainClassifier
from app.assistant.routing import AssistantIntent


class _Response:
    def __init__(self, payload):
        self.payload = payload

    def __enter__(self):
        return self

    def __exit__(self, *_):
        return False

    def read(self):
        text = json.dumps(self.payload)
        body = {"candidates": [{"content": {"parts": [{"text": text}]}}]}
        return json.dumps(body).encode()


class SemanticDomainClassifierTest(unittest.TestCase):
    def classifier(self, **kwargs):
        return SemanticDomainClassifier(api_key="test-key", **kwargs)

    @patch("app.assistant.domain_classifier.request.urlopen")
    def test_routes_semantic_vehicle_question_without_keyword_allowlist(self, urlopen):
        urlopen.return_value = _Response({
            "automotive_relevance": 0.94,
            "assistant_capability": 0.90,
            "intent": "MAINTENANCE",
            "use_rag": False,
            "knowledge_source": "PUBLIC_WEB",
            "tool_name": None,
            "reason": "vehicle maintenance",
            "vehicle_year": None,
            "vehicle_make": None,
            "vehicle_model": None,
            "vehicle_trim": None,
            "vehicle_market": None,
            "clarification_needed": False,
            "clarification_message": None,
        })
        decision = self.classifier().route("Soğuk havalarda tekerlerin havası neden azalıyor?")
        self.assertTrue(decision.in_scope)
        self.assertEqual(AssistantIntent.MAINTENANCE, decision.intent)
        self.assertFalse(decision.use_rag)
        self.assertEqual("PUBLIC_WEB", decision.knowledge_source)

    @patch("app.assistant.domain_classifier.request.urlopen")
    def test_out_of_scope_disables_model_requested_rag_and_tool(self, urlopen):
        urlopen.return_value = _Response({
            "automotive_relevance": 0.08,
            "assistant_capability": 0.02,
            "intent": "USER_VEHICLE",
            "use_rag": False,
            "knowledge_source": "USER_DATA",
            "tool_name": "getMyVehicles",
            "reason": "unrelated",
            "vehicle_year": None,
            "vehicle_make": None,
            "vehicle_model": None,
            "vehicle_trim": None,
            "vehicle_market": None,
            "clarification_needed": False,
            "clarification_message": None,
        })
        decision = self.classifier().route("Bana makarna tarifi ver")
        self.assertFalse(decision.in_scope)
        self.assertEqual(AssistantIntent.OUT_OF_SCOPE, decision.intent)
        self.assertFalse(decision.use_rag)
        self.assertIsNone(decision.tool_name)

    @patch("app.assistant.domain_classifier.request.urlopen")
    def test_rejects_string_boolean_instead_of_treating_false_as_true(self, urlopen):
        urlopen.return_value = _Response({
            "automotive_relevance": 0.9,
            "assistant_capability": 0.9,
            "intent": "VEHICLE_GENERAL",
            "use_rag": "false",
            "knowledge_source": "PUBLIC_WEB",
            "tool_name": None,
            "reason": "invalid shape",
        })
        with self.assertRaises(RuntimeError):
            self.classifier().route("ABS nedir?")


    @patch("app.assistant.domain_classifier.request.urlopen")
    def test_requests_clarification_for_underspecified_vehicle_question(self, urlopen):
        urlopen.return_value = _Response({
            "automotive_relevance": 0.96,
            "assistant_capability": 0.82,
            "intent": "MAINTENANCE",
            "use_rag": False,
            "knowledge_source": "PUBLIC_WEB",
            "tool_name": None,
            "reason": "specific pressure needs vehicle context",
            "vehicle_year": None,
            "vehicle_make": None,
            "vehicle_model": None,
            "vehicle_trim": None,
            "vehicle_market": None,
            "clarification_needed": True,
            "clarification_message": "Araç marka, model ve model yılını paylaşır mısınız?",
        })
        decision = self.classifier().route("Lastik basıncım kaç olmalı?")
        self.assertTrue(decision.in_scope)
        self.assertTrue(decision.clarification_needed)
        self.assertIn("marka", decision.clarification_message)

    def test_rejects_non_finite_scores(self):
        classifier = self.classifier()
        for value in (float("nan"), float("inf"), float("-inf")):
            with self.assertRaises(RuntimeError):
                classifier._score(value)

    def test_explicit_non_positive_timeout_is_rejected(self):
        with self.assertRaises(ValueError):
            self.classifier(timeout_seconds=0)


if __name__ == "__main__":
    unittest.main()
