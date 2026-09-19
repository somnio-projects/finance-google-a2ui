# Developer entry points. `make gate` is the ship gate — identical to CI and to
# .claude/ship-gate.json. Every target runs inside the uv-managed environment.
UV ?= uv
export UV_LINK_MODE ?= copy

.PHONY: install lint format typecheck budget test test-unit test-integration audit gate run migrate purge-audit

install:
	$(UV) sync --all-groups

lint:
	$(UV) run ruff check .
	$(UV) run ruff format --check .

format:
	$(UV) run ruff check --fix .
	$(UV) run ruff format .

typecheck:
	$(UV) run basedpyright

budget:
	$(UV) run python scripts/check_file_budget.py

test:
	$(UV) run pytest --cov --cov-branch --cov-report=term-missing --cov-report=xml

test-unit:
	$(UV) run pytest -m unit --no-cov

test-integration:
	$(UV) run pytest -m integration --no-cov

# Audits the locked runtime dependencies with pip-audit run as an isolated uv tool
# (the project venv has no pip, and pip itself is not a project dependency).
AUDIT_REQ ?= $(or $(TMPDIR),/tmp)/finance-a2ui-requirements.txt
audit:
	$(UV) export --frozen --no-dev --no-emit-project --format requirements-txt -o $(AUDIT_REQ)
	$(UV) tool run --with "pip<26" pip-audit --strict --progress-spinner off --disable-pip -r $(AUDIT_REQ)

# Retention job (docs/compliance/DATA_RETENTION.md): deletes audit_events older than
# AUDIT_RETENTION_DAYS. Needs DATABASE_URL; run monthly (Cloud Scheduler in prod).
purge-audit:
	$(UV) run python -m app.jobs.purge_audit

gate: lint typecheck budget test audit
	@echo "ship gate green"

run:
	$(UV) run uvicorn app.main:app --reload --port 8000

migrate:
	$(UV) run alembic upgrade head
