import unittest
from unittest.mock import Mock

from app.assistant.retriever import SemanticRetriever
from app.assistant.schemas import RetrievedChunk


class SemanticRetrieverTest(unittest.TestCase):
    def test_embeds_query_and_returns_only_final_k(self):
        embedder = Mock()
        embedder.embed_query.return_value = [0.1] * 384
        store = Mock()
        store.search.return_value = [
            RetrievedChunk(i, f"doc-{i}", "Title", "MAINTENANCE", "content", 0.9 - i * 0.01)
            for i in range(6)
        ]
        result = SemanticRetriever(embedder, store).retrieve("Lastik bakımı?", final_k=4)
        self.assertEqual(4, len(result))
        embedder.embed_query.assert_called_once_with("Lastik bakımı?")
        store.search.assert_called_once_with([0.1] * 384, limit=8, min_similarity=0.55)

    def test_blank_question_does_not_embed(self):
        embedder, store = Mock(), Mock()
        self.assertEqual([], SemanticRetriever(embedder, store).retrieve("   "))
        embedder.embed_query.assert_not_called()
        store.search.assert_not_called()


if __name__ == "__main__":
    unittest.main()
