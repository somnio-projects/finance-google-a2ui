# 01 — System context

Who uses finance-a2ui and what it talks to. Source of truth: [ADR-J](../adr/ADR-J-rest-api-and-a2a-surface.md), [`docs/compliance/CLOUD_SERVICES.md`](../compliance/CLOUD_SERVICES.md). Dashed = planned.

```mermaid
flowchart TB
    user(["Reviewer / demo user"])
    subgraph client["Client"]
        flutter["Flutter app<br/>iOS · Android · Web<br/>genui + a2ui_core"]
    end
    subgraph ours["finance-a2ui (our service)"]
        api["Backend<br/>FastAPI · Python 3.12"]
        db[("PostgreSQL 16<br/>sessions · audit · flags")]
    end
    subgraph google["Google"]
        idp["Firebase Auth / Google Identity<br/>OIDC ID tokens"]
        gemini["Gemini API<br/>(planned — GGU-47)"]
    end
    sentry["Sentry<br/>errors, no PII"]

    user --> flutter
    flutter -- "REST /v1/** (bearer)" --> api
    flutter -- "A2A message/stream (bearer)" --> api
    flutter -- "sign in" --> idp
    api -- "verify token via JWKS" --> idp
    api --> db
    api -. "prompts + tool calls" .-> gemini
    api -. "exceptions" .-> sentry

    %% Two surfaces on one service is ADR-J; the client uses REST for reads
    %% and A2A only for the conversation.
```
