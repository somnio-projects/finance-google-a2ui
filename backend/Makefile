# Developer entry points. `make gate` is the ship gate — identical to CI and to
# .claude/ship-gate.json. Every target runs inside the uv-managed environment.
UV ?= uv
export UV_LINK_MODE ?= copy

.PHONY: install lint format typecheck budget catalog catalog-check quality test test-unit test-integration audit gate run migrate purge-audit

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

# The frozen design contract, in both of its renderings: docs/catalog/CONTRACT.md
# for the designer (GGU-41) and docs/catalog/view-catalog.snapshot.json for the
# Flutter catalog test (GGU-53). One render pass over the projection registry,
# never hand-written. `catalog` regenerates both; `catalog-check` fails the gate
# when a projection changed and an artefact did not.
catalog:
	$(UV) run python scripts/generate_catalog_contract.py

catalog-check:
	$(UV) run python scripts/generate_catalog_contract.py --check

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

# Code-smell gates: complexity (xenon), dead code (vulture), docstring coverage
# (interrogate), dependency hygiene (deptry), duplication + design limits (pylint),
# typos (codespell). Thresholds live in pyproject.toml and only ever go up.
quality:
	$(UV) run xenon --max-absolute B --max-modules A --max-average A src
	$(UV) run vulture
	$(UV) run interrogate src
	$(UV) run deptry .
	$(UV) run pylint src/app tests
	$(UV) run codespell src tests docs scripts

gate: lint typecheck budget catalog-check quality test audit
	@echo "ship gate green"

run:
	$(UV) run uvicorn app.main:app --reload --port 8000

migrate:
	$(UV) run alembic upgrade head

# Local development only: an HS256 token the `jwt` provider accepts, so a fresh
# clone can call an authenticated route. Production verifies RS256 via OIDC.
token:
	@set -a; [ -f .env ] && . ./.env; set +a; \
	$(UV) run python scripts/mint_dev_token.py --subject "$(or $(SUBJECT),alice)"
