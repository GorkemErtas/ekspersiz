import re

from .schemas import KnowledgeChunk, KnowledgeDocument


_HEADING_RE = re.compile(r"^(#{1,6})\\s+(.+?)\\s*$")
_TOKEN_RE = re.compile(r"\\S+")


class HeadingAwareChunker:
    """Small dependency-free chunker for curated Markdown knowledge."""

    def __init__(self, target_tokens: int = 420, overlap_tokens: int = 60) -> None:
        if target_tokens < 100:
            raise ValueError("target_tokens must be at least 100")
        if overlap_tokens < 0 or overlap_tokens >= target_tokens:
            raise ValueError("overlap_tokens must be >= 0 and smaller than target_tokens")
        self.target_tokens = target_tokens
        self.overlap_tokens = overlap_tokens

    def chunk(self, document: KnowledgeDocument) -> list[KnowledgeChunk]:
        sections = self._sections(document.content)
        chunks: list[KnowledgeChunk] = []
        index = 0
        for heading, body in sections:
            tokens = _TOKEN_RE.findall(body)
            if not tokens:
                continue
            start = 0
            while start < len(tokens):
                end = min(start + self.target_tokens, len(tokens))
                body_chunk = " ".join(tokens[start:end]).strip()
                content = f"{heading}\n\n{body_chunk}" if heading else body_chunk
                chunks.append(KnowledgeChunk(
                    document_slug=document.slug,
                    chunk_index=index,
                    content=content,
                    heading=heading,
                    metadata={"category": document.category, "heading": heading},
                ))
                index += 1
                if end == len(tokens):
                    break
                start = end - self.overlap_tokens
        return chunks

    @staticmethod
    def _sections(markdown: str) -> list[tuple[str | None, str]]:
        sections: list[tuple[str | None, str]] = []
        heading: str | None = None
        lines: list[str] = []
        for raw_line in markdown.splitlines():
            match = _HEADING_RE.match(raw_line.strip())
            if match:
                if lines:
                    sections.append((heading, "\n".join(lines).strip()))
                heading = match.group(2).strip()
                lines = []
            else:
                lines.append(raw_line)
        if lines:
            sections.append((heading, "\n".join(lines).strip()))
        return sections
