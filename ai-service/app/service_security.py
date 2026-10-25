"""Authenticate before multipart parsing or paid/model work; bound request bodies."""

import hmac
import os

from starlette.exceptions import HTTPException
from starlette.responses import JSONResponse
from starlette.concurrency import run_in_threadpool


class ServiceSecurityMiddleware:
    def __init__(self, app):
        self.app = app
        self.secret = os.getenv("AI_SERVICE_API_KEY", "").encode("utf-8")

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http":
            return await self.app(scope, receive, send)
        if scope["path"] == "/health" and scope["method"] in {"GET", "HEAD"}:
            return await self.app(scope, receive, send)

        if len(self.secret) < 32:
            return await JSONResponse(
                {"detail": "AI service authentication is not configured."}, status_code=503
            )(scope, receive, send)
        credentials = [value for name, value in scope["headers"] if name == b"x-ai-service-key"]
        if len(credentials) != 1 or not hmac.compare_digest(credentials[0], self.secret):
            return await JSONResponse(
                {"detail": "Invalid service credentials."}, status_code=401
            )(scope, receive, send)

        if scope['path'] in {'/api/v1/analyze','/api/v1/validate-image'}:
            from app.damage_analysis.provider import VisionUnavailable
            from app.damage_analysis.api import runtime
            try:
                await run_in_threadpool(runtime.require_available)
            except VisionUnavailable as exc:
                return await JSONResponse({'detail': {'code': 'DAMAGE_ANALYSIS_UNAVAILABLE', 'message': str(exc)}}, status_code=503)(scope, receive, send)

        # Two bounded image parts plus multipart overhead; assistant limit is independent.
        limit = 22 * 1024 * 1024 if scope["path"] in {
            "/api/v1/analyze", "/api/v1/validate-image"
        } else 256 * 1024 if scope["path"] == "/api/v1/assistant/plan" else 64 * 1024
        for name, value in scope["headers"]:
            if name == b"content-length":
                try:
                    if int(value) < 0 or int(value) > limit:
                        raise ValueError()
                except ValueError:
                    return await JSONResponse(
                        {"detail": "Request body is too large."}, status_code=413
                    )(scope, receive, send)

        received = 0

        async def bounded_receive():
            nonlocal received
            message = await receive()
            if message["type"] == "http.request":
                received += len(message.get("body", b""))
                if received > limit:
                    raise HTTPException(status_code=413, detail="Request body is too large.")
            return message

        return await self.app(scope, bounded_receive, send)
