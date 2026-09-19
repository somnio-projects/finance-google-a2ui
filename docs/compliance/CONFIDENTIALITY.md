# Confidentiality Obligations

| | |
|---|---|
| **Owner** | Engineering management (with Somnio HR/Legal) · **Version** 1.0 — 2026-09-19 · **Next review** 2027-09-19 |
| **Maps to** | SOC 2 CC1.4, C1.1 · ISO/IEC 27001 A.6.2, A.6.6 |

## Basis

Every person contributing to this repository does so as a Somnio Software
employee or contractor. Somnio's standard employment and contractor
agreements — held by HR/Legal, not in this repository — contain
confidentiality and intellectual-property clauses that survive the end of the
engagement, and reference the company's information security and acceptable
use policies. **No one receives write access to this repository or access to
a running environment before those agreements are signed** (checked in
[ONBOARDING_OFFBOARDING.md](ONBOARDING_OFFBOARDING.md)).

The Google program relationship is governed by the terms agreed between
Somnio and Google for the A2UI showcase; contributors treat Google program
material shared with the team as Confidential unless Google publishes it.

## What is confidential in this project

Per [DATA_CLASSIFICATION.md](DATA_CLASSIFICATION.md): anything Confidential
or Restricted — audit-trail data, credentials and keys, reviewer account
details, non-public Google program information, incident evidence, unreleased
security findings. The **code is open source** and is not confidential; the
harness and policies are public by design.

## Obligations of every contributor

- Do not copy Confidential/Restricted data outside approved systems (repo secrets, Secret Manager, restricted incident folders).
- Do not paste secrets, tokens or real user data into chat tools, tickets, or AI assistants ([AI_DATA_HANDLING.md](AI_DATA_HANDLING.md)).
- Report suspected disclosure immediately as an incident.
- Return/destroy project data and lose access on leaving (offboarding checklist).

## Breach of obligations

Handled under Somnio's HR disciplinary process (ISO 27001 A.6.4 — CLIENT
lane, not documented here) and, where applicable, the contractual remedies in
the signed agreements.

## Records

The signed-agreement roster is held by Somnio HR; the security owner confirms
"agreement on file: yes" in the onboarding checklist for each new contributor
and in the annual access review.
