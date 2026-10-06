import tempfile
import unittest
from pathlib import Path
from unittest.mock import Mock

from app.assistant.ingestion import KnowledgeIngestionService, KnowledgeSource


class KnowledgeIngestionServiceTest(unittest.TestCase):
    def test_unchanged_document_skips_chunking_and_embeddings(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "lastik.md"
            path.write_text("# Lastik\n\nBasıncı üretici değerine göre kontrol edin.", encoding="utf-8")
            import hashlib
            digest = hashlib.sha256(path.read_text(encoding="utf-8").strip().encode()).hexdigest()

            store, embedder, chunker = Mock(), Mock(), Mock()
            store.find_active_document.return_value = Mock(content_hash=digest)
            service = KnowledgeIngestionService(store, embedder, chunker)

            result = service.ingest(KnowledgeSource(
                path, "MAINTENANCE", "EksperSiz", "2026-10"
            ))

            self.assertEqual("UNCHANGED", result.status)
            chunker.chunk.assert_not_called()
            embedder.embed_passages.assert_not_called()
            store.publish_document.assert_not_called()

    def test_changed_document_is_reembedded_and_published(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "lastik.md"
            path.write_text("# Lastik\n\nYeni içerik.", encoding="utf-8")

            store, embedder, chunker = Mock(), Mock(), Mock()
            store.find_active_document.return_value = Mock(content_hash="old")
            chunker.chunk.return_value = [Mock(content="semantic chunk")]
            embedder.embed_passages.return_value = [[0.1, 0.2]]
            store.publish_document.return_value = 42
            service = KnowledgeIngestionService(store, embedder, chunker)

            result = service.ingest(KnowledgeSource(
                path, "MAINTENANCE", "EksperSiz", "2026-11"
            ))

            self.assertEqual("UPDATED", result.status)
            embedder.embed_passages.assert_called_once()
            store.publish_document.assert_called_once()
            store.replace_chunks.assert_called_once()


if __name__ == "__main__":
    unittest.main()
