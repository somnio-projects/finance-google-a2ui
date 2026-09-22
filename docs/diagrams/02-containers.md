# 02 — Containers and protocols

The deployable pieces. Source of truth: [ADR-F](../adr/ADR-F-persistence-and-session-lifetime.md), [ADR-J](../adr/ADR-J-rest-api-and-a2a-surface.md), [`infra/`](../../infra/README.md). Dashed = planned.

```mermaid
flowchart LR
    client["Browser<br/>(runs a Flutter web bundle)"]
    a2ui["A2UI client<br/>nginx · uid 101 · read-only FS<br/>config compiled in + /release.json"]
    web["client_flutter container<br/>nginx · uid 101 · read-only FS<br/>serves the bundle + /config.json"]
    host["Firebase Hosting<br/>finance-a2ui.web.app<br/>the A2UI client's deployable"]
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

    client -- "GET / · the bundle, then /config.json" --> web
    client -- "GET / · the bundle + /release.json" --> a2ui
    client -- "GET / · the released bundle" --> host
    a2ui -- "same bytes, same build script<br/>(frontend/tool/build_web.sh)" --> host
    web -. "hosting undecided — Cloud Run, bucket+CDN or Firebase<br/>(spec client/0002 OD-1)" .-> edge
    client -- "GET /.well-known/agent-card.json (public)" --> lb
    client -- "POST / · JSON-RPC message/stream · SSE" --> lb
    client -- "GET /v1/** · REST · bearer" --> lb
    lb --> waf --> svc
    svc -- "asyncpg over private VPC" --> sql
    svc -- "secretAccessor per secret" --> sm
    job --> sql
    sched --> job
    svc --> obs
    job --> obs

    %% Two surfaces on one service (ADR-J): /v1/** is strictly RESTful and
    %% answers RFC 9457 problem documents; the root is Google's A2A protocol,
    %% JSON-RPC over SSE, and answers JSON-RPC error objects. The agent card is
    %% the only public route besides the health probes — a client cannot hold a
    %% token before it has read it.
    %% TWO clients, one repository, no shared code (GGU-91). `client_flutter` is
    %% the older one: built and hardened (GGU-82, spec client/0002) but deployed
    %% nowhere — where it is hosted is OD-1, still open, which is why its only
    %% outgoing edge is dashed. The A2UI client is the one this repository is
    %% about, and it IS deployed: Firebase Hosting, by `frontend-cd`
    %% (spec frontend/0017).
    %% The A2UI container is NOT that deployable — Hosting serves a bundle, not
    %% an image. It is the local stack's copy of the same bytes, compiled by the
    %% same `frontend/tool/build_web.sh`, which is why the edge between them is
    %% solid: it is a "built by" relation, not a network call.
    %% Neither container holds a credential; the browser, not the container, is
    %% what talks to the backend. Locally: db + backend, plus the A2UI client on
    %% :3001 behind `--profile frontend` and client_flutter on :3000 behind
    %% `--profile client`, all under the one compose project `finance-a2ui`.
```
