# 0005 — The deployer can reach the jobs it owns

- **Area:** infra (IAM for the delivery service account, and one guard's diagnosis)
- **Status:** In progress
- **Ticket:** _unassigned — no GGU number exists for this; none is invented here_
- **Also:** [`infra/0004`](0004-cd-owns-every-job-image.md) (the change this completes), [`backend/0007`](../backend/0007-cd-pipeline.md) (the pipeline)
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-23

## 1. Problem

Spec `infra/0004` made the deploy point **every** delivery-owned Cloud Run
job at the released digest. The first real deploy after it merged failed:

```
deploying …/backend@sha256:019d2496… to finance-a2ui-dev-api without traffic
candidate revision finance-a2ui-dev-api-00022-rd8
::error::no Cloud Run job carries image-owner=delivery in finance-a2ui/us-central1
  run `terraform apply` for this environment: the label is set in infra/run.tf
::error::could not point every Cloud Run job at the released image
restoring traffic to finance-a2ui-dev-api-00020-qbb
```

**`terraform apply` had already run, and the labels were there.** Verified
against the live project at the moment of the failure:

```console
$ gcloud run jobs describe finance-a2ui-dev-migrate         --format='value(metadata.labels.image-owner)'
delivery
$ gcloud run jobs describe finance-a2ui-dev-purge-audit     --format='value(metadata.labels.image-owner)'
delivery
$ gcloud run jobs describe finance-a2ui-dev-seed-portfolios --format='value(metadata.labels.image-owner)'
delivery
```

Two defects, one symptom.

**The grant never followed the code.** `delivery.tf` gave the deployer
`roles/run.developer` on the **service** and on the **migrate job**, and
nothing else — a deliberate least-privilege choice made when the migration
was the only job the pipeline touched. `infra/0004` changed what the pipeline
touches and left the grant alone. The deployer cannot `run.jobs.list` at all,
and cannot set the image of the two other jobs.

**The guard reported the wrong cause.** `delivery_jobs()` ended in
`2>/dev/null || true`, so a **permission denial** and **an empty result**
were the same value. The caller then printed the only explanation it had and
sent the operator to Terraform, which was not the problem.

## 2. Rulings

- **OD-1 — per job, not project-wide, for the write.** A `for_each` over the
  same three jobs, so a fourth is opted in once — in its own resource block —
  and is reachable by construction. The property the original grant protected
  is kept: the deployer still cannot touch a job nobody opted in.

- **OD-2 — listing is project-level, and that is a real widening.** There is
  no per-job grant that makes a job appear in `gcloud run jobs list`.
  `roles/run.viewer` is the smallest role carrying `run.jobs.list` and it is
  **read-only**; every write stays in the per-job grants. Named here rather
  than left for a reader to infer from a role name.

- **OD-3 — an error that answers the wrong question is worse than no check.**
  The guard keeps stderr now and tells the two cases apart: a denial quotes
  what `gcloud` said, names `run.jobs.list`, points at `delivery.tf` and does
  **not** mention `terraform apply`.

- **OD-4 — why `infra/0004`'s suite could not have caught this.** It stubs
  `gcloud`, so it never meets an IAM decision; every case it runs is about
  what the script does with an *answer*. That is still the right design — the
  suite must not need a cloud — so the new coverage is in two places: a
  stubbed denial (the script's half) and a Terraform assertion that every job
  found in `run.tf` has a binding in `delivery.tf` (the grant's half). Neither
  alone would have failed.

## 3. Acceptance criteria

1. **AC-1** — every Cloud Run job declared in `run.tf` has a `run.developer` binding for the deployer.
2. **AC-2** — the deployer can list jobs, through a read-only project role.
3. **AC-3** — a refused listing exits non-zero, quotes `gcloud`, names the permission and the file, and does not blame Terraform.
4. **AC-4** — an empty list still reports the missing label, unchanged.
5. **AC-5** — `terraform plan` on dev shows only the IAM additions.
6. **AC-6** — the deploy that failed above succeeds.

## 4. Test plan

| AC | How |
|---|---|
| 1, 2 | `test_dev_environment.sh` — the per-job loop gains a binding assertion, and the project role is asserted by name |
| 3 | `test_deploy_cloud_run.sh` case 14 — a stubbed `PERMISSION_DENIED`, asserting all four properties **including** that `terraform apply` is absent |
| 4 | case 12, unchanged and still green — the two cases must read differently |
| 5 | `terraform plan -var-file=environments/dev.tfvars`, output in the PR |
| 6 | the deploy re-run, with `/health` reporting the branch it released |

## 5. Out of scope

Whether the deploy should pin job images at all, versus each job resolving a
tag. That is `infra/0004` and it is settled.
