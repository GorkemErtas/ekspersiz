"""Focused memory lifecycle regression tests; external ML/LLM services are mocked."""
import asyncio
from concurrent.futures import ThreadPoolExecutor
from io import BytesIO
import sys
import time
import types
import unittest
from unittest.mock import AsyncMock, patch

from fastapi import HTTPException

import main
from app.assistant.embeddings import LocalMultilingualEmbedder


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
