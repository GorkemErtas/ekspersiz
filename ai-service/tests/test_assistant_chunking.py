import unittest

from app.assistant.chunking import HeadingAwareChunker
from app.assistant.schemas import KnowledgeDocument


class HeadingAwareChunkerTest(unittest.TestCase):
    def test_preserves_heading_and_creates_overlap(self):
        body = " ".join(f"kelime{i}" for i in range(260))
        document = KnowledgeDocument(
            slug="muayene", title="Muayene", category="INSPECTION",
            content=f"# Muayene Öncesi\n{body}",
        )
        chunks = HeadingAwareChunker(target_tokens=120, overlap_tokens=20).chunk(document)
        self.assertEqual(3, len(chunks))
        self.assertTrue(all(chunk.heading == "Muayene Öncesi" for chunk in chunks))
        first_tokens = chunks[0].content.split()
        second_tokens = chunks[1].content.split()
        self.assertTrue(set(first_tokens[-20:]).intersection(second_tokens))

    def test_empty_sections_are_skipped(self):
        document = KnowledgeDocument(
            slug="x", title="X", category="GENERAL", content="# Empty\n\n## Also Empty\n"
        )
        self.assertEqual([], HeadingAwareChunker().chunk(document))


if __name__ == "__main__":
    unittest.main()
