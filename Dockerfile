# syntax=docker/dockerfile:1

# ============================================================================
# Stage 1: builder — installs dependencies with build tooling available.
# Nothing from this stage ships except the installed packages, so the
# final image carries no pip caches, no build tools, no source metadata.
# ============================================================================
FROM python:3.12-slim AS builder

WORKDIR /build

# Copy only what's needed to resolve dependencies first — this layer is
# cached until pyproject.toml changes, so code-only edits rebuild fast.
COPY pyproject.toml ./
COPY app ./app

# Install the application and its runtime deps into an isolated prefix
# that can be copied wholesale into the runtime stage.
RUN pip install --no-cache-dir --prefix=/install .

# ============================================================================
# Stage 2: runtime — minimal surface. slim base, no compilers, non-root. Ideal
# ============================================================================
FROM python:3.12-slim

# Security hardening:
# - dedicated non-root user with a fixed numeric UID (10001). Kubernetes'
#   `runAsNonRoot` check requires a numeric UID to verify; named users fail it.
# - no shell login, no home directory needed.
RUN groupadd --gid 10001 api \
    && useradd --uid 10001 --gid api --shell /usr/sbin/nologin --no-create-home api

WORKDIR /srv

# Bring in the installed dependencies and the application code.
COPY --from=builder /install /usr/local
COPY app ./app

# Defaults for containerized runs; all overridable via ConfigMap/Secret
# in Kubernetes or `environment:` in compose. No secrets baked in — ever.
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    APP_ENVIRONMENT=production \
    APP_LOG_LEVEL=INFO

USER 10001

EXPOSE 8000

# Docker-level healthcheck for `docker run` / compose. Kubernetes IGNORES
# this and uses its own liveness/readiness probes (Issue #12) — this exists
# for local dev parity. python stdlib is used because slim has no curl.
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health/live', timeout=2)"]

# Exec-form CMD: uvicorn is PID 1 and receives SIGTERM directly, giving
# clean graceful shutdown during Kubernetes rolling updates.
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]


