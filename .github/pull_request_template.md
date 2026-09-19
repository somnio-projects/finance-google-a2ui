<!-- Title: type(scope): description  (Conventional Commits; GGU-n in the branch name) -->

**Spec:** `specs/<area>/NNNN-<feature>.md` <!-- required for any behaviour change -->
**Test decision:** <!-- what is covered by unit vs integration tests and why; mutation checks run -->
**Ticket:** GGU-

## Summary

<!-- What changes and why, in a few sentences. -->

## Verification

- [ ] `cd backend && make gate` green (ruff · format · basedpyright · 150-line budget · pytest 100 % branch · pip-audit)
- [ ] `backend-reviewer` agent run, blockers resolved
- [ ] Migrations included for every schema change; merged revisions untouched
- [ ] Docs updated (`backend/docs/*.md`, `README.md`, `env.example`) and `.claude/harness-log.md` entry appended

## Security & compliance

- [ ] New routes are authenticated (`PrincipalDep`) and audited, or the spec marks them public
- [ ] No secrets, tokens or PII in code, tests, fixtures or logs
- [ ] New dependencies named here with the reason
- [ ] Data handling follows `docs/compliance/DATA_CLASSIFICATION.md` and `DATA_RETENTION.md`
- [ ] Emergency change? Follow `docs/compliance/EMERGENCY_CHANGE.md` and say so here

## Gate output

```text
<!-- paste the tail of `make gate` -->
```
