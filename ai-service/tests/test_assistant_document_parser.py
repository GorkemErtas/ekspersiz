import tempfile
import unittest
from pathlib import Path

from app.assistant.document_parser import DocumentParserRegistry, MarkdownDocumentParser


class AssistantDocumentParserTest(unittest.TestCase):
    def test_markdown_parser_extracts_title_and_content(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "brake.md"
            path.write_text("# Fren Bakımı\n\nBalataları düzenli kontrol edin.", encoding="utf-8")

            parsed = MarkdownDocumentParser().parse(path)

            self.assertEqual("Fren Bakımı", parsed.title)
            self.assertIn("Balataları", parsed.content)

    def test_registry_rejects_unsupported_source(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "source.csv"
            path.write_text("a,b", encoding="utf-8")

            with self.assertRaises(ValueError):
                DocumentParserRegistry().parse(path)


if __name__ == "__main__":
    unittest.main()
