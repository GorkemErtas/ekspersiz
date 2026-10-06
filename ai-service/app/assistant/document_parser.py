from dataclasses import dataclass
from pathlib import Path
from typing import Protocol


@dataclass(frozen=True)
class ParsedDocument:
    title: str
    content: str


class DocumentParser(Protocol):
    def supports(self, path: Path) -> bool: ...
    def parse(self, path: Path) -> ParsedDocument: ...


class MarkdownDocumentParser:
    def supports(self, path: Path) -> bool:
        return path.suffix.lower() in {".md", ".txt"}

    def parse(self, path: Path) -> ParsedDocument:
        content = path.read_text(encoding="utf-8").strip()
        title = next(
            (line.lstrip("# ").strip() for line in content.splitlines()
             if line.startswith("#")),
            path.stem.replace("_", " ").title(),
        )
        return ParsedDocument(title=title, content=content)


class PdfDocumentParser:
    def supports(self, path: Path) -> bool:
        return path.suffix.lower() == ".pdf"

    def parse(self, path: Path) -> ParsedDocument:
        try:
            from pypdf import PdfReader
        except ImportError as exc:
            raise RuntimeError("pypdf is required for PDF knowledge ingestion") from exc

        reader = PdfReader(str(path))
        pages: list[str] = []
        for page_number, page in enumerate(reader.pages, start=1):
            text = self._normalize(page.extract_text() or "")
            if text:
                # Page markers remain metadata-friendly boundaries for future citations.
                pages.append(f"## Page {page_number}\n\n{text}")
        title = (reader.metadata.title if reader.metadata else None) or path.stem.replace("_", " ").title()
        return ParsedDocument(title=title.strip(), content="\n\n".join(pages).strip())

    @staticmethod
    def _normalize(text: str) -> str:
        lines = [" ".join(line.split()) for line in text.splitlines()]
        return "\n".join(line for line in lines if line).strip()


class DocumentParserRegistry:
    def __init__(self, parsers: list[DocumentParser] | None = None) -> None:
        self.parsers = parsers or [MarkdownDocumentParser(), PdfDocumentParser()]

    def parse(self, path: Path) -> ParsedDocument:
        parser = next((candidate for candidate in self.parsers if candidate.supports(path)), None)
        if parser is None:
            raise ValueError(f"Unsupported knowledge document type: {path.suffix}")
        return parser.parse(path)
