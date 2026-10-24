FROM python:3.12-slim

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    HF_HOME=/app/.cache/huggingface \
    ASSISTANT_EMBEDDING_MODEL=intfloat/multilingual-e5-small \
    ASSISTANT_EMBEDDING_LOCAL_ONLY=true

COPY requirements-runtime.txt .

# Package-index URL validation fixes apply to build tooling too.
RUN python -m pip install --no-cache-dir pip==26.2.2

RUN pip install --no-cache-dir \
    torch==2.13.0+cpu \
    --index-url https://download.pytorch.org/whl/cpu

RUN pip install --no-cache-dir -r requirements-runtime.txt

# Bake the pinned embedding model into the image. Production never depends on
# a Hugging Face download during startup or the first assistant request.
RUN ASSISTANT_EMBEDDING_LOCAL_ONLY=false python -c "from sentence_transformers import SentenceTransformer; SentenceTransformer('intfloat/multilingual-e5-small')"

COPY app ./app
COPY knowledge ./knowledge
COPY scripts ./scripts
COPY main.py .

RUN groupadd --system ekspersiz && \
    useradd --system --gid ekspersiz --home-dir /app --no-create-home ekspersiz && \
    chown -R ekspersiz:ekspersiz /app

USER ekspersiz

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
