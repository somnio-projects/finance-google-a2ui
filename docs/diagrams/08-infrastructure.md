# 08 — Production infrastructure (Google Cloud)

What `infra/` creates. **Validated, not applied** — the projects are created with GGU-29. Source of truth: [`infra/README.md`](../../infra/README.md), [`docs/compliance/CLOUD_SERVICES.md`](../compliance/CLOUD_SERVICES.md).

```mermaid
flowchart TB
    net([Internet])
    subgraph gcp["GCP project — one per environment (staging · production)"]
        subgraph edge["Edge"]
            ip["Global anycast IP"]
            https["HTTPS proxy<br/>managed cert · TLS 1.2+ MODERN"]
            armor["Cloud Armor<br/>SQLi · XSS · RCE · LFI · per-IP throttle · adaptive DDoS"]
            httpr["HTTP → HTTPS redirect"]
        end
        subgraph vpc["VPC (private, deny-all ingress, flow logs)"]
            conn["Serverless VPC connector"]
            subgraph runtime["Cloud Run"]
                svc["backend service<br/>min-instances ≥ 1 · uid 10001 · LB-only ingress<br/>probes: /readyz startup, /healthz liveness"]
                job["purge job<br/>audit_events retention"]
            end
            sql[("Cloud SQL PostgreSQL 16<br/>PRIVATE IP · TLS only · REGIONAL HA<br/>daily backups + PITR · 30 retained")]
        end
        sm["Secret Manager<br/>DATABASE_URL · AUTH_JWT_SECRET · SENTRY_DSN · GEMINI_API_KEY<br/>90-day rotation → Pub/Sub"]
        obs["Cloud Logging 90d · data-access audit logs<br/>uptime check /readyz · alerts: readiness, 5xx, auth-failure spike"]
        sched["Cloud Scheduler — monthly"]
        sa(["Runtime service account<br/>cloudsql.client · per-secret accessor · log/metric writer<br/>no owner, no key"])
        subgraph delivery["Delivery (GGU-48)"]
            ar["Artifact Registry<br/>backend images · digest-addressed<br/>keep 20 · drop untagged after 30d"]
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
    svc --> conn --> sql
    sched --> job --> conn
    svc -. "secretAccessor" .-> sm
    job -. "secretAccessor" .-> sm
    svc --> obs
    sa -.->|"identity of"| svc
    sa -.->|"identity of"| job

    %% Everything here is Terraform: infra/{network,database,secrets,iam,run,edge,observability,delivery}.tf
    %% trivy config: 0 misconfigurations. Apply is GGU-29.
    %% The deployer can publish an image and create a revision. It cannot read
    %% a secret, reach the database, or act as any other identity.
```
