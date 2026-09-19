# Breach Notification SLA

| | |
|---|---|
| **Owner** | Engineering management (decision) · Security owner (assessment) |
| **Version** | 1.0 — 2026-09-19 · **Next review** 2027-09-19 |
| **Maps to** | SOC 2 CC7.4, CC9.1, P6.x · ISO/IEC 27001 A.5.26 · GDPR Art. 33/34 (as reference framework) |

## What counts as a breach

Confirmed or reasonably suspected **unauthorised access to, disclosure of,
alteration of, or loss of** information classified Confidential or
Restricted ([DATA_CLASSIFICATION.md](DATA_CLASSIFICATION.md)) — today:
`audit_events` rows (identity subjects, actions), signing secrets, model
keys, telemetry with identifiers. A vulnerability with **no evidence of
exploitation** is an incident, not a breach.

The incident commander assesses with this checklist and records the answer
in the incident issue: (1) which data class was involved; (2) whose data
(internal users, Google reviewer account, none); (3) evidence of exfiltration
or only of exposure; (4) is the data still exposed.

## Who is told, by when (clock starts at breach confirmation)

| Audience | Deadline | Channel | Owner |
|---|---|---|---|
| Engineering management | **1 hour** | Slack + call | IC |
| Somnio leadership / legal | **4 hours** | as directed by management | Eng. management |
| Affected parties (today: Google program contacts and any user whose subject appears in exposed data) | **72 hours** | email from communications lead, template below | Communications + management |
| Regulator (only if personal data of EU/UK residents or other regulated data is involved — not expected for the demo) | **72 hours** from awareness | per jurisdiction, coordinated by Somnio legal | Eng. management |
| Public (open-source users) | with the fix, via GitHub Security Advisory | GitHub | Security owner |

Notification is never delayed to finish the postmortem; a first notice with
what is known is sent within the deadline and updated as facts arrive.

## Notice template

> **Subject:** Security notice — finance-google-a2ui (<date>)
> On <date/time UTC> we identified <what happened> affecting <data / systems>.
> We have <containment actions taken>. Based on current evidence, <what was / was not accessed>.
> Recommended actions for you: <rotate credential / none>.
> Next update by <date/time>. Contact: security@somniosoftware.com.

## Records

Every breach decision (including "not a breach") is recorded in the incident
issue with the checklist answers, and summarised in the postmortem and the
[nonconformity log](isms/NONCONFORMITY_LOG.md).
