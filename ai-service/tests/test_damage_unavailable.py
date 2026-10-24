"""The assistant remains reachable while image analysis fails explicitly."""
import json
import os
import unittest
from unittest.mock import patch

import main
from test_service_security import KEY


class DamageUnavailableTest(unittest.IsolatedAsyncioTestCase):
    async def request(self, path, method="POST", authenticated=True):
        sent = []

        async def receive():
            self.fail("Retired image endpoints must not read or decode uploads")

        async def send(message):
            sent.append(message)

        with patch.dict(os.environ, {"AI_SERVICE_API_KEY": KEY.decode()}):
            app = main.app.build_middleware_stack()
        await app({
            "type": "http", "asgi": {"version": "3.0"}, "http_version": "1.1",
            "method": method, "scheme": "http", "path": path, "root_path": "",
            "query_string": b"", "headers": [(b"x-ai-service-key", KEY)] if authenticated else [],
            "server": ("test", 80), "client": ("127.0.0.1", 1234),
        }, receive, send)
        status = next(item["status"] for item in sent if item["type"] == "http.response.start")
        body = b"".join(item.get("body", b"") for item in sent if item["type"] == "http.response.body")
        return status, json.loads(body)

    async def test_health_reports_service_up_and_damage_unavailable(self):
        status, body = await self.request("/health", "GET", authenticated=False)
        self.assertEqual(200, status)
        self.assertEqual("UP", body["status"])
        self.assertEqual("UNAVAILABLE", body["damageAnalysis"])

    async def test_image_endpoints_require_authentication(self):
        for path in ("/api/v1/analyze", "/api/v1/validate-image"):
            status, _ = await self.request(path, authenticated=False)
            self.assertEqual(401, status)

    async def test_image_endpoints_never_return_a_fabricated_result(self):
        for path in ("/api/v1/analyze", "/api/v1/validate-image"):
            status, body = await self.request(path)
            self.assertEqual(503, status)
            self.assertEqual("DAMAGE_ANALYSIS_UNAVAILABLE", body["detail"]["code"])

    def test_assistant_routes_are_preserved(self):
        paths = {route.path for route in main.app.routes}
        self.assertIn("/api/v1/assistant/plan", paths)
        self.assertIn("/api/v1/assistant/readiness", paths)
