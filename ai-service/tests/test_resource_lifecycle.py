"""Focused memory lifecycle regression tests; external ML/LLM services are mocked."""
from concurrent.futures import ThreadPoolExecutor
import sys
import time
import types
import unittest
from unittest.mock import patch

from app.assistant.embeddings import LocalMultilingualEmbedder


class ResourceLifecycleTest(unittest.TestCase):
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


if __name__ == "__main__":
    unittest.main()
