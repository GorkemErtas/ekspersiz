import unittest
from unittest.mock import Mock
from app.assistant.chunking import HybridSemanticChunker
from app.assistant.schemas import KnowledgeDocument


class HybridSemanticChunkerTest(unittest.TestCase):
    def test_breaks_when_meaning_changes_after_minimum_size(self):
        embedder = Mock()
        embedder.embed_passages.return_value = [
            [1.0, 0.0],
            [0.99, 0.01],
            [0.0, 1.0],
        ]
        p1 = " ".join(["lastik"] * 60)
        p2 = " ".join(["basinc"] * 60)
        p3 = " ".join(["fren"] * 60)
        doc = KnowledgeDocument("bakim", "Bakım", "MAINTENANCE",
                                f"# Bakım\n{p1}\n\n{p2}\n\n{p3}")
        chunks = HybridSemanticChunker(
            embedder, target_tokens=160, min_tokens=100,
            max_tokens=220, similarity_threshold=0.72
        ).chunk(doc)
        self.assertEqual(2, len(chunks))
        self.assertIn("lastik", chunks[0].content)
        self.assertIn("fren", chunks[1].content)
        self.assertEqual("hybrid-semantic-v1", chunks[0].metadata["chunking"])

    def test_heading_is_hard_semantic_boundary(self):
        embedder = Mock()
        embedder.embed_passages.side_effect = [
            [[1.0, 0.0]], [[1.0, 0.0]]
        ]
        doc = KnowledgeDocument(
            "x", "X", "SAFETY",
            "# ABS\nABS uyarısı kontrol edilmelidir.\n\n# Airbag\nAirbag uyarısı kontrol edilmelidir."
        )
        chunks = HybridSemanticChunker(
            embedder, target_tokens=100, min_tokens=50, max_tokens=150
        ).chunk(doc)
        self.assertEqual(["ABS", "Airbag"], [c.heading for c in chunks])


if __name__ == "__main__":
    unittest.main()
