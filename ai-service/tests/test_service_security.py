import os
import unittest
from unittest.mock import patch

from fastapi import FastAPI, Request
from app.service_security import ServiceSecurityMiddleware

KEY = b"test-service-key-at-least-32-characters"


async def request(app, path="/api/v1/assistant/plan", headers=(), chunks=(b"{}",), method="POST"):
    sent = []
    reads = 0
    async def receive():
        nonlocal reads
        body = chunks[reads]
        reads += 1
        return {"type": "http.request", "body": body, "more_body": reads < len(chunks)}
    async def send(message):
        sent.append(message)
    await app({"type": "http", "asgi": {"version": "3.0"}, "http_version": "1.1",
               "method": method, "scheme": "http", "path": path, "root_path": "",
               "query_string": b"", "headers": list(headers), "server": ("test", 80),
               "client": ("127.0.0.1", 1234)}, receive, send)
    return next(m["status"] for m in sent if m["type"] == "http.response.start"), reads


class ServiceSecurityTest(unittest.IsolatedAsyncioTestCase):
    def app(self, secret=KEY.decode()):
        app = FastAPI()
        self.operations = 0
        @app.post("/api/v1/assistant/plan")
        async def plan(req: Request):
            await req.body()
            self.operations += 1
            return {"ok": True}
        @app.get("/health")
        async def health():
            return {"status": "UP"}
        with patch.dict(os.environ, {"AI_SERVICE_API_KEY": secret}):
            return ServiceSecurityMiddleware(app)

    async def test_missing_or_wrong_credentials_rejected_before_reading_body(self):
        for headers in ((), ((b"x-ai-service-key", b"wrong"),),
                        ((b"x-ai-service-key", KEY), (b"x-ai-service-key", KEY))):
            app = self.app()
            status, reads = await request(app, headers=headers)
            self.assertEqual((401, 0), (status, reads))
            self.assertEqual(0, self.operations)

    async def test_missing_configuration_fails_closed_but_health_works(self):
        app = self.app("")
        self.assertEqual(503, (await request(app))[0])
        self.assertEqual(200, (await request(app, "/health", method="GET"))[0])
        self.assertEqual(503, (await request(app, "/health", method="POST"))[0])

    async def test_authenticated_backend_request_runs_once(self):
        status, _ = await request(self.app(), headers=((b"x-ai-service-key", KEY),))
        self.assertEqual(200, status)
        self.assertEqual(1, self.operations)

    async def test_content_length_limit_rejects_before_body(self):
        status, reads = await request(self.app(), headers=(
            (b"x-ai-service-key", KEY), (b"content-length", b"65537")))
        self.assertEqual((413, 0), (status, reads))

    async def test_chunked_body_cannot_bypass_limit(self):
        status, _ = await request(self.app(), headers=((b"x-ai-service-key", KEY),),
                                  chunks=(b"x" * 40000, b"x" * 40000))
        self.assertEqual(413, status)
        self.assertEqual(0, self.operations)
