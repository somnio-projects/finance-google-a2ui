# Documented Information Control Procedure

| | |
|---|---|
| **Owner** | Security owner (TL backend) · **Version** 1.0 — 2026-09-19 · **Next review** 2027-09-19 |
| **Maps to** | ISO/IEC 27001 Cl. 7.5 |

## Principle

Git is the document management system. Every ISMS document lives in this
repository, so creation, review, approval, versioning, distribution and
retention are the same controlled process as for code.

## Rules

| Requirement (Cl. 7.5) | How it is met |
|---|---|
| Identification and description | every policy starts with the header block: Owner · Approved by · Version · Last/Next review · Maps to; file names are `UPPER_SNAKE_CASE.md` under `docs/compliance/` (ISMS artifacts under `isms/`) |
| Format and media | Markdown in git; rendered on GitHub; diagrams as text |
| Review and approval | a pull request; **approval = merge by a code owner** (`/docs/compliance/` is owned by the security owner; management-approved documents name the approver in the header and management approves the PR) |
| Version | `Version` in the header is bumped on substantive change (1.0 → 1.1 editorial, → 2.0 material); the git history is the full change record with author, date and diff |
| Distribution and access | public repository — policies are readable by anyone; evidence containing Confidential data (incident folders, pentest reports, exported rulesets) goes to `docs/compliance/evidence/` only if Public/Internal, otherwise to a restricted Somnio drive referenced by link |
| Storage and preservation | GitHub with branch protection on `main`; local clones; retention indefinite for policies, per DATA_RETENTION.md for evidence |
| Control of changes | CODEOWNERS review; harness log entry when the change is part of an iteration; the `Last review` date updated even when nothing changes at the annual review |
| Retention and disposition | superseded documents keep a one-line pointer to the replacement for one review cycle, then are deleted (history remains in git) |
| Documents of external origin | vendor reports (SOC 2, ISO certificates) are linked, not copied, in VENDOR_MANAGEMENT.md |

## Document lifecycle

Draft (PR open) → Reviewed (approving review) → Approved/Published (merged to
`main`) → Reviewed annually (date bump) → Superseded/Withdrawn (pointer, then
removal).

## Templates

Policy header block (copy):

```markdown
| | |
|---|---|
| **Owner** | <role> · **Approved by** <role> · **Version** 1.0 — YYYY-MM-DD · **Next review** YYYY-MM-DD |
| **Maps to** | SOC 2 <criteria> · ISO/IEC 27001 <clauses / Annex A> |
```
