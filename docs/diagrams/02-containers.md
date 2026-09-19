# 02 — Containers and protocols

The deployable pieces. Source of truth: [ADR-F](../adr/ADR-F-persistence-and-session-lifetime.md), [ADR-J](../adr/ADR-J-rest-api-and-a2a-surface.md), [`infra/`](../../infra/README.md). Dashed = planned.

```mermaid
flowchart LR
    subgraph edge["Edge (planned — infra/edge.tf)"]
        lb["HTTPS Load Balancer<br/>managed cert · TLS 1.2+"]
        waf["Cloud Armor<br/>OWASP · per-IP throttle"]
    end
    subgraph run["Cloud Run (planned — infra/run.tf)"]
        svc["backend service<br/>uid 10001 · read-only FS"]
        job["purge job<br/>python -m app.jobs.purge_audit"]
    end
    subgraph data["Data"]
        sql[("Cloud SQL PostgreSQL 16<br/>private IP · regional HA · PITR")]
        sm["Secret Manager<br/>90-day rotation"]
    end
    obs["Cloud Logging / Monitoring<br/>90-day retention · alerts"]
    sched["Cloud Scheduler<br/>monthly"]

    lb --> waf --> svc
    svc -- "asyncpg over private VPC" --> sql
    svc -- "secretAccessor per secret" --> sm
    job --> sql
    sched --> job
    svc --> obs
    job --> obs

    %% Today the same shape runs locally as docker compose: db + backend only.
```
