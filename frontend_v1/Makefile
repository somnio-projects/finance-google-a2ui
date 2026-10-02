# Developer entry points for the A2UI v1.0 finance client (frontend_v1/,
# ADR-M D-9) — a copy of frontend/'s Makefile plus `catalog`/`catalog-check`.
#
# `make gate` is the ship gate — identical to the `quality` and `tests` jobs
# of .github/workflows/frontend-ci.yaml and to the `frontend.*` entries in
# ../.claude/ship-gate.json. (That workflow also builds the web bundle, which
# is slow and belongs on a runner — the same split as backend-ci's `image`
# job.) When you change one, change its pair: `.claude/rules/ci-conventions.md`
# §5 exists because a paraphrase drifted until a finding reached `develop`.
PACKAGES := packages/a2ui_v1 packages/finance_core packages/finance_api_client packages/finance_views_repository packages/finance_charts packages/finance_auth
PACKAGE_CONFIG := $(CURDIR)/.dart_tool/package_config.json
LCOV := app/coverage/lcov.info \
	packages/a2ui_v1/coverage/lcov.info \
	packages/finance_core/coverage/lcov.info \
	packages/finance_api_client/coverage/lcov.info \
	packages/finance_views_repository/coverage/lcov.info \
	packages/finance_charts/coverage/lcov.info \
	packages/finance_auth/coverage/lcov.info

.PHONY: install toolchain toolchain-test verify-release-test format format-check \
	analyze budget manifest manifest-check catalog catalog-check csp test test-tool test-packages test-app \
	coverage gate clean

# The first thing the gate proves, because everything after it is read through
# `dart` and `flutter` (GGU-94). The pinned version lives in `.fvmrc` — one
# file, read here, by frontend-ci.yaml's SDK setup step and by the Dockerfile. Without this,
# a machine carrying the wrong Dart announced itself as three unformatted files
# and exit 65, which reads like a red branch and is not one.
toolchain:
	bash tool/check_toolchain.sh

# The preflight's own suite, with a stubbed SDK on PATH. It is here because
# `toolchain` is the first gate step for the whole frontend — a false failure
# blocks everything behind it — and because on a runner it can never be seen
# rejecting, since CI installs exactly the pinned SDK. Its rejection paths have
# nowhere else to be exercised.
toolchain-test:
	bash tool/tests/test_check_toolchain.sh

# The delivery check's own suite, with a stubbed curl. `verify_release.sh` is
# what turns "frontend-cd's deploy step exited 0" into "the origin is serving
# this commit", and on a runner it can only ever be seen accepting — the
# deploy it follows has just succeeded. Its rejection paths have nowhere else
# to be exercised, which is the same argument `toolchain-test` makes and the
# same one `repo.manual-run` makes for the backend's evidence check.
verify-release-test:
	bash tool/tests/test_verify_release.sh

# The CSP the *deployed* client is served under, which no local run and no
# widget test can see. `firebase_core_web` boots the Firebase JS SDK from an
# inline script; a strict `script-src` blocks it and the app renders a white
# page with only a console line to say why. This derives the hash of that
# script from the resolved plugin and proves both policies — Hosting's
# `firebase.json` and the container's nginx template — authorise it.
csp:
	bash tool/check_csp_hashes.sh

# --enforce-lockfile from day one. Plain `pub get` silently re-resolves, so a
# build can differ from the one that was reviewed; the strict flag fails
# instead of quietly changing the dependency graph.
install: toolchain
	flutter pub get --enforce-lockfile

format:
	dart format .

format-check:
	dart format --output=none --set-exit-if-changed .

analyze:
	dart analyze --fatal-infos --fatal-warnings

budget:
	dart run tool/check_file_budget.dart

# The component manifest is generated from the directories under
# app/lib/components. `manifest` rewrites it; `manifest-check` fails the gate
# when a component was added and the file was not regenerated — the same
# "gated by regeneration, never by trust" rule as the backend's frozen catalog.
manifest:
	dart run tool/generate_component_manifest.dart

manifest-check:
	dart run tool/generate_component_manifest.dart --check

# The bundle's copy of the A2UI v1.0 catalog (ADR-M D-4/D-5). `catalog`
# copies the backend's generated docs/a2ui/v1.0/finance.catalog.json into
# app/assets; `catalog-check`
# fails when the copy is stale, so the renderer never enforces rules the
# backend no longer emits.
catalog:
	bash tool/sync_catalog.sh

catalog-check:
	bash tool/sync_catalog.sh --check

test: test-tool test-packages test-app

# The gate's own scripts. They are not under lib/, so the coverage contract
# does not reach them — which is exactly why they need a suite of their own:
# `check_coverage.dart` used to pass on a walk that found no files at all.
test-tool:
	dart test test

test-packages:
	@for package in $(PACKAGES); do \
		echo "== $$package"; \
		( cd $$package && dart test --coverage=coverage \
			&& dart run coverage:format_coverage --lcov --in=coverage \
				--out=coverage/lcov.info --packages=$(PACKAGE_CONFIG) \
				--report-on=lib ) || exit 1; \
	done

test-app:
	cd app && flutter test --coverage

# 100 % line coverage per file. Dart's tooling emits line hits only — there is
# no branch data in lcov for Dart — so the backend's 100 % *branch* contract
# cannot be reproduced literally; this is the strongest honest equivalent.
# The threshold lives in tool/check_coverage.dart and only ever goes up.
coverage:
	dart run tool/check_coverage.dart $(LCOV)

gate: toolchain toolchain-test verify-release-test format-check analyze budget \
	manifest-check catalog-check csp test coverage
	@echo "frontend_v1 ship gate green"

clean:
	flutter clean
	rm -rf app/coverage packages/*/coverage
