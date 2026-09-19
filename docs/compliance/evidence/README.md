# Evidence exports

Machine-readable snapshots that back statements in the policies. Refreshed at
each internal audit ([../isms/INTERNAL_AUDIT_PROGRAM.md](../isms/INTERNAL_AUDIT_PROGRAM.md));
only Public/Internal material lives here — Confidential evidence (incident
folders, pentest reports) is linked from the policies to a restricted drive.

| File | What | Exported | State it shows |
|---|---|---|---|
| `branch-protection-ruleset.json` | `gh api repos/somnio-projects/finance-google-a2ui/rulesets/23483982` | 2026-09-19 | ruleset `main` exists (deletion, non-fast-forward, pull-request rules) but `enforcement: disabled`, 0 required approvals, no code-owner review — **to be enabled before PR #2 merges** (RISK_ASSESSMENT treatment plan; SoA A.5.3/A.8.4) |

Planned additions: `iam-policy.json` (GCP, with GGU-29), `pentest/` (external
report summary), CI artifact links (coverage, SBOM, Trivy SARIF).
