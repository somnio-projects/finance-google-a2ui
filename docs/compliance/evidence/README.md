# Evidence exports

Machine-readable snapshots that back statements in the policies. Refreshed at
each internal audit ([../isms/INTERNAL_AUDIT_PROGRAM.md](../isms/INTERNAL_AUDIT_PROGRAM.md));
only Public/Internal material lives here — Confidential evidence (incident
folders, pentest reports) is linked from the policies to a restricted drive.

| File | What | Exported | State it shows |
|---|---|---|---|
| `branch-protection-ruleset.json` | `gh api repos/somnio-projects/finance-google-a2ui/rulesets/23483982` | 2026-09-19 (re-exported after enabling) | ruleset **`protected-branches`, enforcement `active`** on `refs/heads/main` **and** `refs/heads/develop`: pull request required with **1 code-owner approval**, stale approvals dismissed on push, review threads must be resolved, **squash merges only**, force-push and deletion blocked |

Planned additions: `iam-policy.json` (GCP, with GGU-29), `pentest/` (external
report summary), CI artifact links (coverage, SBOM, Trivy SARIF).
