# Information Security Policy

| | |
|---|---|
| **Owner** | Security owner — Lautaro Bertuzzi (TL backend) |
| **Approved by** | Engineering management — Guillermo Hilal (merge of this document = approval) |
| **Version** | 1.0 — 2026-09-19 |
| **Last review / Next review** | 2026-09-19 / 2027-09-19 (annual) or on material change |
| **Maps to** | SOC 2 CC1.1, CC1.3, CC5.1 · ISO/IEC 27001 Cl. 5.2, 5.3, 6.2, A.5.1, A.5.2, A.5.4 |

## 1. Policy statement

Somnio Software builds finance-google-a2ui as an open-source reference
application. Even without client data, we operate it as if it carried
confidential financial information, because the point of the showcase is to
demonstrate how such a system should be built. Management commits to protect
the **confidentiality, integrity and availability** of the information the
service processes — user identities, audit trails, model credentials — and
to run an information security management system (ISMS) proportionate to a
small, cloud-native engineering team.

## 2. Scope

The ISMS scope is defined in [`isms/ISMS_SCOPE.md`](isms/ISMS_SCOPE.md):
the `backend/` service, its data (PostgreSQL), its CI/CD, the Claude Code
harness, and the people who develop and operate them. The Flutter client is
in scope for secure development, out of scope for data at rest (it stores
nothing). Cloud provider physical/network security is inherited under the
shared-responsibility model ([`CLOUD_SERVICES.md`](CLOUD_SERVICES.md)).

## 3. Objectives

Measurable objectives and their metrics are in
[`isms/SECURITY_OBJECTIVES.md`](isms/SECURITY_OBJECTIVES.md). Headline:

1. Every request authenticated and every privileged action audited — 100 % of routes except health probes.
2. No known CRITICAL/HIGH vulnerability older than the [`PATCH_POLICY.md`](PATCH_POLICY.md) SLA on `main`.
3. Zero secrets in the repository or images (gitleaks + Trivy gates green on every merge).
4. RPO ≤ 24 h / RTO ≤ 4 h for the database ([`BUSINESS_CONTINUITY_PLAN.md`](BUSINESS_CONTINUITY_PLAN.md)); one restore drill per quarter.
5. Somnio CLI `security-audit`, `soc2-audit`, `iso27001-audit` ≥ 90 at every foundation milestone.

## 4. Roles and responsibilities (RACI)

| Activity | Security owner (TL backend) | Backend engineers | PM / integrator | Eng. management |
|---|---|---|---|---|
| Maintain this policy set, SoA, risk register | **R/A** | C | I | A (approval) |
| Implement and test controls in code | A | **R** | I | I |
| Review security-critical PRs (`.github/CODEOWNERS`) | **R/A** | C | I | I |
| Triage vulnerabilities within SLA | **R** | R | I | A |
| Incident commander (default) | **R/A** | R | C (comms) | I |
| Breach notification decision | R | C | C | **A** |
| Vendor risk review / DPAs | R | I | C | **A** |
| Access reviews (quarterly) | **R/A** | I | I | I |
| Management review (semi-annual) | R | I | C | **A** |
| Security training completion | A | **R** | R | I |

R = responsible, A = accountable, C = consulted, I = informed. Named people
are in [`../../CONTRIBUTORS.md`](../../CONTRIBUTORS.md). The security owner
role is a designated responsibility of the TL backend, not a separate hire.

## 5. Management commitment

Engineering management commits to: provide the time to keep the gates
green rather than waive them; fund an external penetration test before any
non-demo exposure of the service; review this policy and the risk register
at least annually; and treat a red ship gate as "not done".

## 6. Principles every contributor follows

- **Least privilege** — scopes in tokens, `admin` only for feature-flag operations, non-root read-only containers.
- **Secure by default** — required settings have no defaults; production refuses wildcards; docs hidden in production.
- **Defence in depth** — auth, rate limit, body limit, security headers, audit trail, error masking, scanners.
- **No secrets in code** — `SecretStr`, `.env` denied to tooling, gitleaks on every commit.
- **Evidence over assertion** — every control names its test in `backend/docs/SECURITY.md`; every policy names its owner and review date.
- **Blameless learning** — incidents end in a postmortem, not a search for a culprit.

## 7. Policy set

The individual policies, standards and runbooks that implement this policy are
indexed in [`README.md`](README.md). Deviations follow
[`EXCEPTION_POLICY.md`](EXCEPTION_POLICY.md). Violations are handled through
Somnio's HR process (reference: [`CONFIDENTIALITY.md`](CONFIDENTIALITY.md)).

## 8. Review

Reviewed annually by the security owner and approved by engineering management
in the management review ([`isms/MANAGEMENT_REVIEW.md`](isms/MANAGEMENT_REVIEW.md)).
Version history is the git history of this file
([`isms/DOCUMENT_CONTROL.md`](isms/DOCUMENT_CONTROL.md)).
