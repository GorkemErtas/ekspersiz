import math
import re

from .schemas import KnowledgeChunk, KnowledgeDocument

_HEADING_RE = re.compile(r"^(#{1,6})\\s+(.+?)\\s*$")
_TOKEN_RE = re.compile(r"\\S+")


def _cosine(a: list[float], b: list[float]) -> float:
    return sum(x * y for x, y in zip(a, b, strict=True))


class HybridSemanticChunker:
    """Heading + paragraph + local-embedding semantic chunker.

    Boundaries are chosen from semantic similarity while hard token limits
    prevent pathological chunks. No paid embedding API is required.
    """

    def __init__(self, embedder, target_tokens: int = 420,
                 min_tokens: int = 120, max_tokens: int = 560,
                 similarity_threshold: float = 0.72) -> None:
        if not 50 <= min_tokens <= target_tokens <= max_tokens:
            raise ValueError("Expected min_tokens <= target_tokens <= max_tokens")
        if not 0.0 < similarity_threshold < 1.0:
            raise ValueError("similarity_threshold must be between 0 and 1")
        self.embedder = embedder
        self.target_tokens = target_tokens
        self.min_tokens = min_tokens
        self.max_tokens = max_tokens
        self.similarity_threshold = similarity_threshold

    def chunk(self, document: KnowledgeDocument) -> list[KnowledgeChunk]:
        chunks: list[KnowledgeChunk] = []
        index = 0
        for heading, body in self._sections(document.content):
            paragraphs = self._paragraphs(body)
            if not paragraphs:
                continue
            units = self._split_oversized(paragraphs)
            vectors = self.embedder.embed_passages(units)
            current: list[str] = []
            current_tokens = 0
            previous_vector = None

            for unit, vector in zip(units, vectors, strict=True):
                unit_tokens = self._token_count(unit)
                semantic_break = (
                    previous_vector is not None
                    and current_tokens >= self.min_tokens
                    and _cosine(previous_vector, vector) < self.similarity_threshold
                )
                size_break = current and current_tokens + unit_tokens > self.max_tokens
                target_break = (
                    current and current_tokens >= self.target_tokens
                    and previous_vector is not None
                    and _cosine(previous_vector, vector) < self.similarity_threshold + 0.08
                )
                if semantic_break or size_break or target_break:
                    chunks.append(self._make_chunk(document, index, heading, current))
                    index += 1
                    current = []
                    current_tokens = 0

                current.append(unit)
                current_tokens += unit_tokens
                previous_vector = vector

            if current:
                chunks.append(self._make_chunk(document, index, heading, current))
                index += 1
        return chunks

    def _split_oversized(self, paragraphs: list[str]) -> list[str]:
        result: list[str] = []
        for paragraph in paragraphs:
            tokens = _TOKEN_RE.findall(paragraph)
            if len(tokens) <= self.max_tokens:
                result.append(paragraph)
                continue
            for start in range(0, len(tokens), self.target_tokens):
                result.append(" ".join(tokens[start:start + self.target_tokens]))
        return result

    @staticmethod
    def _paragraphs(body: str) -> list[str]:
        return [re.sub(r"\\s+", " ", p).strip()
                for p in re.split(r"\\n\\s*\\n", body) if p.strip()]

    @staticmethod
    def _token_count(text: str) -> int:
        return len(_TOKEN_RE.findall(text))

    @staticmethod
    def _make_chunk(document: KnowledgeDocument, index: int,
                    heading: str | None, units: list[str]) -> KnowledgeChunk:
        body = "\n\n".join(units).strip()
        content = f"{heading}\n\n{body}" if heading else body
        return KnowledgeChunk(
            document_slug=document.slug,
            chunk_index=index,
            content=content,
            heading=heading,
            metadata={
                **document.metadata,
                "category": document.category,
                "heading": heading,
                "chunking": "hybrid-semantic-v1",
            },
        )

    @staticmethod
    def _sections(markdown: str) -> list[tuple[str | None, str]]:
        sections: list[tuple[str | None, str]] = []
        heading = None
        lines: list[str] = []
        for raw_line in markdown.splitlines():
            match = _HEADING_RE.match(raw_line.strip())
            if match:
                if lines and "\n".join(lines).strip():
                    sections.append((heading, "\n".join(lines).strip()))
                heading = match.group(2).strip()
                lines = []
            else:
                lines.append(raw_line)
        if lines and "\n".join(lines).strip():
            sections.append((heading, "\n".join(lines).strip()))
        return sections


# Kept for compatibility with existing callers/tests. New ingestion uses HybridSemanticChunker.
class HeadingAwareChunker:
    def __init__(self, target_tokens: int = 420, overlap_tokens: int = 60) -> None:
        if target_tokens < 100:
            raise ValueError("target_tokens must be at least 100")
        if overlap_tokens < 0 or overlap_tokens >= target_tokens:
            raise ValueError("overlap_tokens must be >= 0 and smaller than target_tokens")
        self.target_tokens = target_tokens
        self.overlap_tokens = overlap_tokens

    def chunk(self, document: KnowledgeDocument) -> list[KnowledgeChunk]:
        chunks = []
        index = 0
        for heading, body in HybridSemanticChunker._sections(document.content):
            tokens = _TOKEN_RE.findall(body)
            start = 0
            while start < len(tokens):
                end = min(start + self.target_tokens, len(tokens))
                text = " ".join(tokens[start:end])
                chunks.append(HybridSemanticChunker._make_chunk(document, index, heading, [text]))
                index += 1
                if end == len(tokens):
                    break
                start = end - self.overlap_tokens
        return chunks
