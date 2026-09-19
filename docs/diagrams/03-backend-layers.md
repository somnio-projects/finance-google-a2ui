# 03 — Backend layers

Dependencies point inward, always. Source of truth: [`.claude/rules/backend/architecture.md`](../../.claude/rules/backend/architecture.md), [`.claude/rules/backend/presentation.md`](../../.claude/rules/backend/presentation.md).

```mermaid
flowchart TB
    subgraph http["HTTP edge"]
        mw["middleware<br/>request id · security headers · trusted host<br/>CORS · body limit · rate limit"]
        ctl["api/v1/*.py<br/>controllers: resolve Depends, call ONE service"]
        deps["api/deps.py<br/>the only place services are constructed"]
        oapi["api/openapi.py<br/>shared problem responses · tags"]
    end
    subgraph app["Application"]
        svc["services/*.py<br/>use cases, authorization, audit"]
        pres["presentation/*<br/>projections: (data, options) → DTO (pure)"]
    end
    subgraph core["Domain and contracts"]
        dom["domain/*<br/>portfolio, lots, prices (pure, Decimal)"]
        agt["agent/*<br/>Tool Protocol · registry · prompt · tools"]
        cor["core/<br/>Settings · AppError · Protocols · Principal · display · trend"]
        cor["core/<br/>Settings · AppError · Protocols · Principal · display"]
    end
    subgraph infra["Infrastructure"]
        repo["repositories/*.py<br/>the only SQLAlchemy users"]
        mdl["models/*.py<br/>ORM entities + Alembic"]
        adp["infra/<br/>db engine · telemetry · model client"]
        auth["auth/providers/*<br/>TokenVerifier implementations"]
    end
    boot["bootstrap.py — the single composition root"]

    mw --> ctl --> deps
    ctl --> oapi
    deps --> svc
    svc --> pres
    svc --> dom
    svc --> agt --> dom
    svc --> repo --> mdl
    svc --> cor
    agt --> cor
    adp --> cor
    auth --> cor
    boot -.->|"wires everything, imported by nobody"| deps

    %% Forbidden and checked in review: services importing FastAPI/SQLAlchemy,
    %% controllers importing repositories, presenters doing I/O.
    %% agent/ is an inner layer beside domain/: core + domain only, nothing
    %% outward — asserted over the parsed source by the boundary tests.
```
