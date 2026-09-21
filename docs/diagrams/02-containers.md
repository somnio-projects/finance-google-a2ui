# 02 — Containers and protocols

The deployable pieces. Source of truth: [ADR-F](../adr/ADR-F-persistence-and-session-lifetime.md), [ADR-J](../adr/ADR-J-rest-api-and-a2a-surface.md), [`infra/`](../../infra/README.md). Dashed = planned.

```mermaid
flowchart LR
    client["Browser<br/>(runs the Flutter web bundle —<br/>still the upstream sample)"]
    web["client container<br/>nginx · uid 101 · read-only FS<br/>serves the bundle + /config.json"]
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
    %% The client container is built and hardened (GGU-82, spec client/0002) but
    %% is not deployed anywhere: where it is hosted is OD-1, still open, which is
    %% why its only outgoing edge is dashed. It serves static bytes and holds no
    %% credential; the browser, not the container, is what talks to the backend.
    %% Today the same shape runs locally as docker compose: db + backend, plus
    %% the client on :3000 behind `--profile client`.
```
