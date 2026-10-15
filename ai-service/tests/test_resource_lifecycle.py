"""Focused memory lifecycle regression tests; external ML/LLM services are mocked."""
import asyncio
from concurrent.futures import ThreadPoolExecutor
from io import BytesIO
import sys
import threading
import time
import types
import unittest
from unittest.mock import AsyncMock, patch

from fastapi import HTTPException

import main
from app.assistant.embeddings import LocalMultilingualEmbedder
from app.memory_reclaim import trim_unused_heap_if_enabled


class ResourceLifecycleTest(unittest.TestCase):
    def test_assistant_health_import_does_not_initialize_yolo(self):
        self.assertIsNone(main._damage_analyzer)

    def test_first_image_call_initializes_analyzer_once_across_threads(self):
        constructed = []

        class FakeDamageAnalyzer:
            def __init__(self):
                time.sleep(0.01)
                constructed.append(self)

        fake_module = types.ModuleType("app.damage_analyzer")
        fake_module.DamageAnalyzer = FakeDamageAnalyzer
        with patch.dict(sys.modules, {"app.damage_analyzer": fake_module}):
            with patch.object(main, "_damage_analyzer", None):
                with ThreadPoolExecutor(max_workers=8) as executor:
                    instances = list(executor.map(
                        lambda _: main.get_damage_analyzer(), range(16)
                    ))
                self.assertEqual(1, len(constructed))
                self.assertTrue(all(value is constructed[0] for value in instances))

    def test_inference_is_serialized_across_threads(self):
        active = 0
        max_active = 0
        gate = threading.Lock()

        class FakeDamageAnalyzer:
            def analyze(self, *, file_content, filename):
                nonlocal active, max_active
                with gate:
                    active += 1
                    max_active = max(max_active, active)
                time.sleep(0.02)
                with gate:
                    active -= 1
                return filename

        with patch.object(main, "_damage_analyzer", FakeDamageAnalyzer()):
            with ThreadPoolExecutor(max_workers=8) as executor:
                results = list(executor.map(
                    lambda i: main.run_damage_operation(
                        "analyze", file_content=b"image", filename=str(i)
                    ),
                    range(16),
                ))
        self.assertEqual([str(i) for i in range(16)], results)
        self.assertEqual(1, max_active)

    def test_image_inference_does_not_block_the_event_loop(self):
        started = threading.Event()
        finish = threading.Event()

        def slow_inference(operation, **kwargs):
            started.set()
            finish.wait(timeout=2)
            return "done"

        image = types.SimpleNamespace(
            filename="vehicle.jpg",
            content_type="image/jpeg",
            read=AsyncMock(return_value=b"picture"),
            close=AsyncMock(),
        )

        async def exercise():
            task = asyncio.create_task(main.analyze_damage(image, context_image=None, vehicle_region=None))
            try:
                was_started = await asyncio.wait_for(
                    asyncio.to_thread(started.wait, 0.7), timeout=1
                )
                self.assertTrue(was_started)
                self.assertFalse(task.done())
                self.assertEqual("UP", main.health_check()["status"])
            finally:
                finish.set()
            return await asyncio.wait_for(task, timeout=1)

        with patch.object(main, "run_damage_operation", slow_inference):
            self.assertEqual("done", asyncio.run(exercise()))
        image.close.assert_awaited_once()

    def test_heap_reclamation_is_opt_in(self):
        with patch.dict("os.environ", {"AI_TRIM_HEAP_AFTER_INFERENCE": "false"}):
            with patch("app.memory_reclaim._malloc_trim") as stub:
                self.assertFalse(trim_unused_heap_if_enabled())
                stub.assert_not_called()

    def test_heap_reclamation_only_calls_native_trim_when_enabled(self):
        calls = []
        with patch.dict("os.environ", {"AI_TRIM_HEAP_AFTER_INFERENCE": "true"}):
            with patch("app.memory_reclaim._malloc_trim", return_value=lambda x: calls.append(x) or 1):
                self.assertTrue(trim_unused_heap_if_enabled())
        self.assertEqual([0], calls)

    def test_run_operation_releases_native_heap_after_return(self):
        class FakeDamageAnalyzer:
            def validate_image_quality(self, *, file_content, purpose):
                return purpose
        with patch.object(main, "_damage_analyzer", FakeDamageAnalyzer()):
            with patch("main.trim_unused_heap_if_enabled") as reclaim:
                output = main.run_damage_operation(
                    "validate_image_quality", file_content=b"jpeg", purpose="context"
                )
                self.assertEqual("context", output)
                reclaim.assert_called_once_with()

    def test_embedding_first_load_is_singleton_across_threads(self):
        constructed = []

        class FakeSentenceTransformer:
            def __init__(self, model, *, local_files_only):
                time.sleep(0.01)
                constructed.append((model, local_files_only))

        fake_module = types.ModuleType("sentence_transformers")
        fake_module.SentenceTransformer = FakeSentenceTransformer
        embedder = LocalMultilingualEmbedder()
        with patch.dict(sys.modules, {"sentence_transformers": fake_module}):
            with patch.dict("os.environ", {"ASSISTANT_EMBEDDING_LOCAL_ONLY": "true"}):
                with ThreadPoolExecutor(max_workers=8) as executor:
                    loaded = list(executor.map(
                        lambda _: embedder._load(), range(16)
                    ))
        self.assertEqual([(embedder.model_name, True)], constructed)
        self.assertTrue(all(model is loaded[0] for model in loaded))

    def test_upload_read_is_bounded_before_size_validation(self):
        file = types.SimpleNamespace(
            content_type="image/jpeg",
            read=AsyncMock(return_value=b"valid"),
        )
        self.assertEqual(b"valid", asyncio.run(main.read_valid_image(file)))
        file.read.assert_awaited_once_with(main.MAX_IMAGE_SIZE_BYTES + 1)

    def test_oversized_upload_still_returns_413(self):
        file = types.SimpleNamespace(
            content_type="image/jpeg",
            read=AsyncMock(return_value=b"x" * (main.MAX_IMAGE_SIZE_BYTES + 1)),
        )
        with self.assertRaises(HTTPException) as failure:
            asyncio.run(main.read_valid_image(file))
        self.assertEqual(413, failure.exception.status_code)


if __name__ == "__main__":
    unittest.main()
