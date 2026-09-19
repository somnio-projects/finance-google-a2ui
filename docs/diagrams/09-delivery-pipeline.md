# 09 — Where each check runs

Cheap checks locally, expensive ones once. Source of truth: [`.claude/rules/ci-conventions.md`](../../.claude/rules/ci-conventions.md), `.github/workflows/`. Dashed = planned (GGU-48).

```mermaid
flowchart LR
    subgraph dev["Developer machine — free"]
        edit["edit"]
        pc["pre-commit<br/>hygiene · gitleaks · ruff · codespell<br/>actionlint · terraform fmt · basedpyright<br/>150-line budget · quality suite · unit tests"]
        pp["pre-push<br/>make gate (full, with PostgreSQL)"]
    end
    subgraph ci["GitHub Actions — paid, only what a laptop cannot prove"]
        q["Quality · style, types, complexity, duplication"]
        t["Tests · pytest 100% branch on PostgreSQL 16 service container"]
        s["Security · gitleaks full history · Semgrep · pip-audit"]
        img["Container · build · non-root · Trivy CVE"]
        rep["Report · ship-gate summary"]
    end
    subgraph after["After merge"]
        cd["CD: build → Artifact Registry → Cloud Run<br/>(planned — GGU-48)"]
        wk["Weekly scheduled scan<br/>pip-audit + SBOM · Trivy SARIF · gitleaks"]
    end

    edit --> pc --> pp --> pr["Pull request → develop"]
    pr --> q & t & s
    q --> img
    t --> img
    q & t & s & img --> rep
    rep --> merge["Squash merge<br/>1 code-owner approval"]
    merge -.-> cd
    merge --> wk

    %% concurrency cancel-in-progress · paths filters · caches · needs:
    %% so a branch that fails lint never pays for an image build.
```
