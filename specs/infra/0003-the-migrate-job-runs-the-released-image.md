# 0003 — The migrate job runs the image being released

- **Area:** infra (the delivery script and its suite)
- **Status:** In progress
- **Ticket:** _unassigned — no GGU number exists for this yet; none is invented here_
- **Also:** [backend/0007](../backend/0007-cd-pipeline.md) (the pipeline this corrects), [infra/0001](0001-dev-environment.md) §10a (Terraform and the pipeline own different fields), [infra/0002](0002-firebase-sign-in-on-dev.md) (the deploy that exposed it)
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-22

## 1. Problem

On 2026-09-22 a deploy of `develop` to dev failed with:

```
FAILED: Can't locate revision identified by '0007'
migrations failed; the schema was not moved
restoring traffic to finance-a2ui-dev-api-00014-hdd
```

The migration chain was not broken — `0001 → … → 0007` is contiguous on
`develop`, and the *service* was already running the code that contains
`0007`. Measured on the live service:

| Resource | Image |
|---|---|
| `finance-a2ui-dev-api` | `backend@sha256:4e00948…` (today's release) |
| `finance-a2ui-dev-migrate` | `backend@sha256:afd9e97…` (an older build) |

**`gcloud run jobs execute` runs whatever image the job carries, and nothing
in this repository ever set it.** `deploy_cloud_run.sh` executed the job and
passed only `--update-env-vars=APP_RELEASE`; `infra/run.tf` declares the job's
image as `var.backend_image` and then ignores changes to it —
`ignore_changes = [template[0].template[0].containers[0].image]` — precisely so
the pipeline could own the field. Neither side owned it. The job kept the
image it was created with, for every deploy after the first.

The script's own comment asserted the opposite: *"the job runs on the image
being released"*. That sentence was false and no test read it, because **the
suite had no case for the migrate step at all** — 44 assertions covering the
deploy, the readiness gate, the traffic shift, five rollbacks and the
rollback-to-revision path, and none for the one step that touches the schema.

It stayed invisible for a second reason: the service also carries
`RUN_MIGRATIONS=true`, so the new revision migrated at container start. The
schema therefore *did* move to `0007` — by the service — and the job, running
older code that had never heard of `0007`, then failed reading the version
table. The error read like a broken migration chain and was a stale image.

## 2. What ships

`migrate()` sets the job's image before running it, through the same
`gcloud_run` helper every other call uses:

```bash
if ! gcloud_run jobs update "${job}" --image="${IMAGE}"; then
  return 1
fi
```

A failure to set it is a failure of the step, which the caller already turns
into a rollback with traffic untouched. Two cases join the suite (now 50
assertions):

| Case | Asserts |
|---|---|
| 1 (extended) | the job is pointed at the released digest; the update happens **before** the execute; the migration happens **before** the traffic shift |
| 10 | `jobs update` fails → the job is never executed on an unknown image, nothing takes traffic, the previous revision is restored |
| 11 | the migration fails → the update was attempted on the released digest, nothing takes traffic, the summary records the rollback |

**Mutation-checked**, the way this suite asks: delete the `jobs update` line and
six assertions go red (`points the migrate job at the released image`, `sets the
job's image BEFORE running it`, and the four in case 10). Restore it and the
suite is 50/50 green.

## 3. Rulings

- **OD-1 — the pipeline owns the job's image, as Terraform already assumed.**
  The `ignore_changes` on the job was written for an owner that did not exist;
  this adds the owner rather than removing the ignore. Terraform keeps the
  shape (command, env, secrets, service account); the deploy keeps naming
  *which build* runs — the same division as the service (0001 §10a).
- **OD-2 — `RUN_MIGRATIONS=true` on the service stays, for now.** It is what
  masked this defect, and the script's own comment calls migrating at
  container start wrong (two booting instances race through Alembic's version
  table). Removing it here would be a second, larger change with a hazard of
  its own: the deploy creates the revision **before** the job runs, so a
  container that does not migrate at boot would start on the old schema — and
  the admin registry's bootstrap (backend/0027 OD-2) runs at boot. Ordering
  that correctly is its own spec. What this one fixes is the false claim.
- **OD-3 — the step that moves the schema is the step that most needed a
  test.** Not a general lesson about coverage: the suite's own header states
  the rollback is the point of the exercise, and every rollback *reason* was
  covered except the one that had never been executed with the right code.

## 4. Verification

- `bash infra/scripts/tests/test_deploy_cloud_run.sh` — **50 passed, 0 failed**;
  with the fix reverted, 6 fail.
- `bash scripts/check_shell.sh`, `bash scripts/check_gate_pairs.sh`,
  `bash scripts/check_spelling.sh` — green.
- Not run here: a deploy. Releasing is a human's button (CLAUDE.md), and the
  first run of this script after merge is its real proof: the job's image must
  equal the service's afterwards.
