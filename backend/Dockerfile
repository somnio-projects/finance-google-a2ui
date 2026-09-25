# syntax=docker/dockerfile:1.7
# Multi-stage build: dependencies are resolved from uv.lock in a builder stage,
# the runtime image carries only the virtualenv and the source, runs as a
# non-root user with a read-only filesystem (see docker-compose.yml).

FROM python:3.14-slim AS builder
ENV UV_LINK_MODE=copy UV_COMPILE_BYTECODE=1 UV_PYTHON_DOWNLOADS=never
RUN pip install --no-cache-dir uv==0.11.19
WORKDIR /app
COPY pyproject.toml uv.lock README.md ./
COPY src ./src
RUN uv sync --frozen --no-dev --no-editable

FROM python:3.14-slim AS runtime
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PATH="/app/.venv/bin:$PATH" PORT=8000
# Pull Debian security updates so the image does not ship base-layer CVEs
# (Trivy gates CRITICAL/HIGH in CI); perl-base is only a dpkg dependency here.
RUN apt-get update \
 && apt-get upgrade -y --no-install-recommends \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*
RUN groupadd --system --gid 10001 app && useradd --system --uid 10001 --gid app --no-create-home app
WORKDIR /app
COPY --from=builder --chown=app:app /app/.venv ./.venv
COPY --chown=app:app alembic.ini ./
COPY --chown=app:app alembic ./alembic
COPY --chown=app:app src ./src
COPY --chown=app:app docker/entrypoint.sh ./entrypoint.sh
USER app
EXPOSE 8000
HEALTHCHECK --interval=15s --timeout=3s --start-period=10s --retries=3 \
  CMD ["python", "-c", "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=2).status == 200 else 1)"]
ENTRYPOINT ["./entrypoint.sh"]
