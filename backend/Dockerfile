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
# The runtime installs nothing: the virtualenv arrives built from the builder
# stage and PATH points into it. The base image's own pip is therefore dead
# weight — and on python:3.14-slim it is what Trivy gates on, because pip
# 26.2.1 *vendors* msgpack 1.1.2 (GHSA-6v7p-g79w-8964) and setuptools 70.3.0
# (CVE-2025-47273), both HIGH and both fixed upstream. Neither is a dependency
# of this service, neither is importable from the venv, and no version of
# uv.lock can move them: they live in pip/_vendor. Deleting pip drops both
# findings and shrinks the image. The glob keeps the interpreter version out
# of this path, so it is not a sixth place declaring it.
RUN rm -rf /usr/local/lib/python3*/site-packages/pip \
           /usr/local/lib/python3*/site-packages/pip-*.dist-info \
           /usr/local/bin/pip /usr/local/bin/pip3 /usr/local/bin/pip3.*
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
