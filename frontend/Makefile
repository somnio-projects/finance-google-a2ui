# Developer entry points for the A2UI finance client.
#
# `make gate` is the ship gate — identical to .github/workflows/frontend-ci.yaml
# and to the `dart.*` / `flutter.*` entries in ../.claude/ship-gate.json. When
# you change one, change its pair: `.claude/rules/ci-conventions.md` §5 exists
# because a paraphrase drifted until a finding reached `develop`.
PACKAGES := packages/finance_core packages/finance_api_client packages/finance_views_repository
PACKAGE_CONFIG := $(CURDIR)/.dart_tool/package_config.json
LCOV := app/coverage/lcov.info \
	packages/finance_core/coverage/lcov.info \
	packages/finance_api_client/coverage/lcov.info \
	packages/finance_views_repository/coverage/lcov.info

.PHONY: install format format-check analyze budget manifest manifest-check \
	test test-packages test-app coverage gate clean

# --enforce-lockfile from day one. Plain `pub get` silently re-resolves, so a
# build can differ from the one that was reviewed; the strict flag fails
# instead of quietly changing the dependency graph.
install:
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

test: test-packages test-app

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

gate: format-check analyze budget manifest-check test coverage
	@echo "frontend ship gate green"

clean:
	flutter clean
	rm -rf app/coverage packages/*/coverage
