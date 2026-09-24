# 02 — Containers and protocols

The deployable pieces. Source of truth: [ADR-F](../adr/ADR-F-persistence-and-session-lifetime.md), [ADR-J](../adr/ADR-J-rest-api-and-a2a-surface.md), [`infra/`](../../infra/README.md). Dashed = planned.

```mermaid
flowchart LR
    client["Browser<br/>(runs a Flutter web bundle)"]
    a2ui["A2UI client<br/>nginx · uid 101 · read-only FS<br/>config compiled in + /release.json"]
    host["Firebase Hosting<br/>finance-a2ui.web.app<br/>the A2UI client's deployable"]
    subgraph edge["Edge (planned — infra/edge.tf)"]
        lb["HTTPS Load Balancer<br/>managed cert · TLS 1.2+"]
        waf["Cloud Armor<br/>OWASP · per-IP throttle"]
    end
    subgraph run["Cloud Run (planned — infra/run.tf)"]
        svc["backend service<br/>uid 10001 · read-only FS"]
        job["purge job<br/>python -m app.jobs.purge_audit"]
        mig["migrate job<br/>alembic upgrade head<br/><i>the deploy runs it</i>"]
        seed["seed job<br/>python -m app.jobs.seed_portfolios<br/><i>a HUMAN runs it</i>"]
    end
    subgraph data["Data"]
        sql[("Cloud SQL PostgreSQL 16<br/>private IP · regional HA · PITR")]
        sm["Secret Manager<br/>90-day rotation"]
    end
    obs["Cloud Logging / Monitoring<br/>90-day retention · alerts"]
    sched["Cloud Scheduler<br/>monthly"]

    client -- "GET / · the bundle + /release.json" --> a2ui
    client -- "GET / · the released bundle" --> host
    a2ui -- "same bytes, same build script<br/>(frontend/tool/build_web.sh)" --> host
    client -- "GET /.well-known/agent-card.json (public)" --> lb
    client -- "POST / · JSON-RPC message/stream · SSE" --> lb
    client -- "GET /v1/** · REST · bearer" --> lb
    lb --> waf --> svc
    svc -- "asyncpg over private VPC" --> sql
    svc -- "secretAccessor per secret" --> sm
    job --> sql
    mig --> sql
    seed --> sql
    sched --> job
    svc --> obs
    job --> obs

    %% Two surfaces on one service (ADR-J): /v1/** is strictly RESTful and
    %% answers RFC 9457 problem documents; the root is Google's A2A protocol,
    %% JSON-RPC over SSE, and answers JSON-RPC error objects. The agent card is
    %% the only public route besides the health probes — a client cannot hold a
    %% token before it has read it.
    %% ONE client. This diagram carried a second one, `client_flutter`, built
    %% and hardened (GGU-82, spec client/0002) but deployed nowhere — its only
    %% outgoing edge was dashed because where it would be hosted was never
    %% decided. It was retired on 2026-09-22 (spec repo/0002) and both its node
    %% and that dashed edge are gone with it: a diagram draws reality.
    %% The A2UI client IS deployed: Firebase Hosting, by `frontend-cd`
    %% (spec frontend/0017).
    %% The A2UI container is NOT that deployable — Hosting serves a bundle, not
    %% an image. It is the local stack's copy of the same bytes, compiled by the
    %% same `frontend/tool/build_web.sh`, which is why the edge between them is
    %% solid: it is a "built by" relation, not a network call.
    %% The container holds no credential; the browser, not the container, is
    %% what talks to the backend. Locally `docker compose up` is db + backend +
    %% the A2UI client on :3001, all under the one project `finance-a2ui`.
```
