# Production Dockerfile — works for Cloud Run, Render, Koyeb, Fly.io, HF Spaces
FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential curl && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

COPY . .

# Cloud Run injects PORT dynamically; default 8080 locally
ENV PORT=8080

HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
    CMD curl -fsS http://localhost:${PORT}/healthz || exit 1

EXPOSE 8080

# Shell form so $PORT expands at runtime
CMD exec uvicorn main:app --host 0.0.0.0 --port ${PORT:-8080}
