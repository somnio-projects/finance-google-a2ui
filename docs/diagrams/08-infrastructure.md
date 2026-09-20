# 08 — Infrastructure (Google Cloud)

What `infra/` creates, and what differs between `dev` and production. **Validated, not applied** — the project is provisioned with GGU-29, dev first. Source of truth: [`infra/README.md`](../../infra/README.md), [`docs/compliance/CLOUD_SERVICES.md`](../compliance/CLOUD_SERVICES.md), [`specs/infra/0001-dev-environment.md`](../../specs/infra/0001-dev-environment.md).

Nodes labelled *production only* are counted out of `dev` by `local.ephemeral` in `main.tf`; dashed edges are the dev-only paths that replace them.

```mermaid
flowchart TB
    net([Internet])
    subgraph gcp["GCP project — one per environment (dev · staging · production)"]
        subgraph edge["Edge — PRODUCTION ONLY, absent in dev"]
            ip["Global anycast IP"]
            https["HTTPS proxy<br/>managed cert · TLS 1.2+ MODERN"]
            armor["Cloud Armor<br/>SQLi · XSS · RCE · LFI · per-IP throttle · adaptive DDoS"]
            httpr["HTTP → HTTPS redirect"]
        end
        subgraph vpc["VPC (private, deny-all ingress, flow logs)"]
            conn["Serverless VPC connector<br/>(production only — dev uses<br/>Cloud Run direct VPC egress)"]
            subgraph runtime["Cloud Run"]
                svc["backend service · uid 10001<br/>prod: min-instances ≥ 1, LB-only ingress<br/>dev: scales to zero, open ingress, run.app URL<br/>probes: /readyz startup, /healthz liveness"]
                job["purge job<br/>audit_events retention"]
            end
            sql[("Cloud SQL PostgreSQL 16<br/>PRIVATE IP · TLS only — both environments<br/>prod: REGIONAL HA · PITR · 30 backups<br/>dev: ZONAL · no PITR · 2 backups · destroyable")]
        end
        sm["Secret Manager<br/>DATABASE_URL · AUTH_JWT_SECRET · SENTRY_DSN · GEMINI_API_KEY<br/>90-day rotation → Pub/Sub"]
        obs["Cloud Logging 90d (dev 30d) · data-access audit logs<br/>alerts: 5xx, auth-failure spike<br/>uptime check /readyz + readiness alert: production only"]
        sched["Cloud Scheduler — monthly"]
        sa(["Runtime service account<br/>cloudsql.client · per-secret accessor · log/metric writer<br/>no owner, no key"])
        subgraph delivery["Delivery (GGU-48) — develop→dev, main→production, both behind a green gate"]
            ar["Artifact Registry<br/>backend images · digest-addressed<br/>keep 20 (dev 5) · drop untagged after 30d"]
            wif["Workload Identity pool + provider<br/>issuer token.actions.githubusercontent.com<br/>condition: assertion.repository == this repo"]
            dsa(["Deployer service account<br/>artifactregistry.writer · run.developer<br/>serviceAccountUser on the runtime SA only<br/>NO KEY"])
        end
    end

    gha["GitHub Actions<br/>backend-cd"] -->|"OIDC token"| wif
    wif -->|impersonates| dsa
    dsa -->|push by digest| ar
    dsa -->|create revision, shift traffic| svc
    ar -->|image| svc

    net --> ip --> https --> armor --> svc
    net --> httpr --> https
    net -. "dev only: run.app, no LB in front" .-> svc
    svc --> conn --> sql
    svc -. "dev only: direct VPC egress" .-> sql
    sched --> job --> conn
    job -. "dev only: direct VPC egress" .-> sql
    svc -. "secretAccessor" .-> sm
    job -. "secretAccessor" .-> sm
    svc --> obs
    sa -.->|"identity of"| svc
    sa -.->|"identity of"| job

    %% Everything here is Terraform: infra/{network,database,secrets,iam,run,edge,observability,delivery}.tf
    %% trivy config: 0 misconfigurations. Apply is GGU-29.
    %% The edge subgraph and the connector are counted out of dev by local.ephemeral
    %% (main.tf). Dev therefore has NO WAF, NO edge rate limit and NO HA — a real
    %% reduction, accepted as risk R-16 because dev holds synthetic data only.
    %% Secrets, per-secret IAM, private DB IP, TLS-only and the keyless pipeline
    %% are identical in every environment: dev gives up durability, not privacy.
    %% The deployer can publish an image and create a revision. It cannot read
    %% a secret, reach the database, or act as any other identity.
```

## What dev does not have

| Absent in dev | Still present in dev |
|---|---|
| Cloud Armor WAF, edge rate limit, adaptive DDoS | the application's bearer auth, per-principal rate limiter, error masking, audit events |
| Load balancer, reserved IP, managed certificate, TLS policy | TLS on Cloud Run's own certificate |
| Regional HA, PITR, 30 backups, deletion protection | daily backups (2 retained), synthetic data only |
| Uptime check and readiness alert | 5xx and auth-failure alerts; the deploy's own `/healthz` verify-and-rollback |
| Always-on VPC connector, warm instance | private database IP, TLS-only, `PRIVATE_RANGES_ONLY` egress, deny-all ingress |

Full reasoning and the compliance record: [`specs/infra/0001-dev-environment.md`](../../specs/infra/0001-dev-environment.md) §5, §8.
