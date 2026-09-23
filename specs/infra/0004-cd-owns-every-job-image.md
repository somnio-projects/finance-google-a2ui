# 0004 — CD owns every Cloud Run job's image

- **Area:** infra (the delivery script, its suite, and the Terraform that declares the jobs)
- **Status:** In progress
- **Ticket:** _unassigned — no GGU number exists for this yet; none is invented here_
- **Also:** [infra/0003](0003-the-migrate-job-runs-the-released-image.md) (the same defect, found in one job), [backend/0007](../backend/0007-cd-pipeline.md) (the pipeline), [infra/0001](0001-dev-environment.md) §10a (Terraform and the pipeline own different fields), [backend/0035](../backend/0035-the-portfolio-has-an-owner-and-the-tabs-really-filter.md) §4.1 (the seed job)
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-22

## 1. Problem

Spec 0003 fixed the migrate job's image by name. On 2026-09-22, deploying dev
and then seeding the demo audience:

```
$ gcloud run jobs execute finance-a2ui-dev-seed-portfolios --region us-central1 \
    --args="lbertuzzi@somniosoftware.com,demo@somnio.dev" --wait
… failed with exit code 1
$ gcloud logging read … --freshness=20m
Container called exit(1).
/app/.venv/bin/python: No module named app.jobs.seed_portfolios
```

The module was on `develop`. The image was not: `seed-portfolios` was created
by Terraform from `var.backend_image`, which on dev is the **floating tag**
`us-central1-docker.pkg.dev/finance-a2ui/finance-a2ui-dev/backend:latest`, and
nothing had ever moved it. It was worked around by hand —
`gcloud run jobs update … --image=<the service's digest>` — after which it
seeded correctly (`{"seeded": 2, "skipped": 0, "total": 2}`). That fix lived
nowhere but in the live job.

Measured the same evening, the three jobs and the service:

| Resource | Image it would run |
|---|---|
| `finance-a2ui-dev-api` (service) | `backend@sha256:faf8e43…` — the release |
| `finance-a2ui-dev-migrate` | `backend@sha256:faf8e43…` — spec 0003 works |
| `finance-a2ui-dev-seed-portfolios` | `backend@sha256:854327a4…` — **the hand-fix, already one release stale** |
| `finance-a2ui-dev-purge-audit` | `backend:latest` → `sha256:03073e2a…` — **a floating tag, never moved** |

Two things are worth naming separately.

**The hand-fix was already stale by the time it was written up.** One deploy
later the service had moved to `faf8e43` and the seed job had not. Fixing an
image by hand fixes one execution.

**`purge-audit` is the worse of the two, and nobody was looking at it.** It is
the only job with an *unattended* trigger — Cloud Scheduler, 03:00 UTC on the
1st — and it deletes rows from `audit_events` under a documented retention
policy. It was going to run whatever `:latest` happened to point at. A
compliance control executing unknown code monthly is a control in name only.

**And `terraform apply` was armed to undo the hand-fix.** Measured on `dev`
before this change, with no local edits:

```
  # google_cloud_run_v2_job.seed_portfolios will be updated in-place
      ~ image = "…/backend@sha256:854327a4…" -> "…/backend:latest"
```

So the repository contained, simultaneously: a deploy that pinned one job, a
Terraform configuration that would revert a second to a mutable tag, and a
comment in `infra/run.tf` arguing that this was correct.

## 2. Scope

**In:**

- `deploy_cloud_run.sh` points **every** delivery-owned Cloud Run job at the
  released digest, before the migration and before the traffic shift.
- The set of jobs is **derived from a label Terraform declares**, not from a
  list in the pipeline.
- `purge_audit` and `seed_portfolios` gain `lifecycle { ignore_changes }` on
  their image, as `migrate` already had.
- Both suites grow the assertions that fail when this returns.

**Out:**

- Removing `RUN_MIGRATIONS=true` from the service. Still the open question
  spec 0003 OD-2 left; unchanged here.
- The residual `terraform plan` noise on dev (`client`/`client_version`
  metadata, the service's `APP_RELEASE`). Pre-existing, unrelated, §4.
- Production and staging. The same code applies to them; neither has been
  created, so neither has been measured.

## 3. What ships

### 3.1 The declaration (Terraform)

```hcl
delivery_owned_labels = merge(local.labels, { "image-owner" = "delivery" })
```

Each of the three jobs carries it, and each carries

```hcl
lifecycle {
  ignore_changes = [template[0].template[0].containers[0].image]
}
```

### 3.2 The derivation (the deploy)

```bash
delivery_jobs() {
  gcloud_run jobs list --filter="metadata.labels.image-owner=delivery" \
    --format='value(metadata.name)' 2>/dev/null || true
}
```

`point_jobs_at_image` runs after the readiness gate and before `migrate`, so
the migration is covered by the same pass. `migrate()` no longer sets its own
image — doing it in the step that happens to execute a job is how the other
two were missed.

## 4. Rulings

### OD-1 — the job list is DERIVED, and the derivation reads a DECLARATION

Three shapes were available.

| Shape | Adding a fourth job | Can it touch a job nobody meant to? |
|---|---|---|
| a list of names in `deploy_cloud_run.sh` | edit the pipeline, remembering to | no |
| a name prefix (`finance-a2ui-dev-*`) | nothing to do | **yes** — anything matching the prefix |
| a label Terraform sets | one line, in the job's own resource block | no — opting in is explicit |

The label wins because it is the only one that is both. Adding a job is one
line **in the file you already have open**, and the set is still closed: a job
that must stay pinned simply does not carry the label. The prefix form is the
one the brief warned about — it derives the set from whatever happens to be
deployed, which is how a deploy updates something nobody meant to touch.

`purge-audit` **belongs in the same treatment**, and this is the argument, not
a convenience: the question a job answers is not *who runs me* but *which
build am I*. Those came apart because the previous reasoning bundled them. The
deploy now answers the second for all three and still answers the first for
none of them — it executes exactly one job, the migration, and
`test_dev_environment.sh` asserts that count.

**The derivation reads the cloud, so it can be wrong in a way a list cannot,
and it is guarded twice.** `gcloud run jobs list --filter=…image-owner=delivery`
answers with a warning and **exit 0** when nothing carries the label —
measured against the live project before this was applied. A deploy that read
that as "no jobs to pin" would be green having pinned nothing, which is this
defect wearing the fix's clothes. So: an empty list is a hard failure naming
`terraform apply`, and a list that does not contain the migrate job is a hard
failure too, because a non-empty list is not a correct list. Same anti-vacuity
idiom as `scripts/check_shell.sh`.

### OD-2 — a job pinned to a floating tag is not configuration, it is a trap

`var.backend_image` stays, because a resource has to be created with *some*
image, and it keeps naming `:latest` on dev. What changes is that nothing
reads it after creation: every job now declares `ignore_changes` on its image,
as the service already did. The variable's description now says **bootstrap**
and says why.

The alternative — dropping `ignore_changes` and having Terraform hold the
digest — was rejected. It makes every release an `apply`, puts an image digest
in a `.tfvars` file, and hands the pipeline and Terraform the same field to
write. Spec 0001 §10a already settled that division: Terraform owns the shape,
the deploy owns which build runs. Two of the three jobs were simply outside it.

### OD-3 — the reversal in `infra/run.tf` is kept in the file, not deleted

That block argued *against* `ignore_changes` on the seed job, on the grounds
that freezing it at the applied image would make a human run stale code months
later. The hazard was real and the conclusion was backwards: without an owner,
what it froze at was a mutable tag, which is stale code with no floor at all.
Both failure modes are one sentence — *the build that runs is not the build
that was released* — and the fix for both is an owner. The old reasoning stays
above the new, because a reader who only sees the answer will make the same
trade again.

## 5. Acceptance criteria

1. **AC-1** — the deploy points every job labelled `image-owner=delivery` at
   the released digest, before the migration and before the traffic shift.
2. **AC-2** — it executes exactly one job, the migration. `purge-audit` and
   `seed-portfolios` are pinned and never run.
3. **AC-3** — an empty job list, or one without the migrate job, fails the
   deploy with traffic untouched and a message naming the fix.
4. **AC-4** — a failure to set any job's image is a hard stop: nothing is
   executed, nothing takes traffic, the previous revision is restored.
5. **AC-5** — a Cloud Run job in `run.tf` without the label, or without
   `ignore_changes` on its image, turns `test_dev_environment.sh` red.
6. **AC-6** — `terraform plan` on dev no longer proposes changing any job's
   image.

## 6. Test plan

| AC | Where | Asserts |
|---|---|---|
| AC-1 | `test_deploy_cloud_run.sh` case 1 | all three jobs updated to the digest; discovered by label; pinned before the shift; the migrate job's image set before its execute |
| AC-2 | case 1 + `test_dev_environment.sh` | no `jobs execute` for purge-audit or seed-portfolios; the script contains exactly one `gcloud run jobs execute` and it runs `${MIGRATE_JOB}` |
| AC-3 | cases 12, 13 | empty list → exit non-zero, nothing updated or executed, message names `image-owner=delivery` and `terraform apply`; list without migrate → names the missing job |
| AC-4 | case 10 | `jobs update` fails → no execute, no traffic, previous restored |
| AC-5 | `test_dev_environment.sh` | a loop over every `google_cloud_run_v2_job` found in `run.tf`, with an anti-vacuity floor of three |
| AC-6 | `terraform plan` | §7 |

Counts: `test_deploy_cloud_run.sh` 50 → **68**, `test_dev_environment.sh`
76 → **79**.

**Mutation-checked**, five ways:

| Mutation | Result |
|---|---|
| drop `ignore_changes` from `seed_portfolios` | 1 fail |
| drop the label from `purge_audit` | 1 fail |
| **add a fourth job with neither** | 2 fails, naming it |
| delete the `point_jobs_at_image` call | 20 fails |
| make an empty job list a no-op | 6 fails |

The third is the one that matters: the check is not a fixture of three names,
it is a rule about jobs.

## 7. Verification

Run, all green:

- `bash infra/scripts/tests/test_deploy_cloud_run.sh` — 68 passed, 0 failed
- `bash infra/scripts/tests/test_dev_environment.sh` — 79 passed, 0 failed
- `bash infra/scripts/tests/test_wif_conditions.sh`,
  `test_rules_index.sh`, `test_rate_limit_ceiling.sh`
- `bash scripts/check_shell.sh`, `check_spelling.sh`, `check_gate_pairs.sh`
- `bash scripts/tests/test_check_manual_run.sh`
- `terraform fmt -check -recursive`, `terraform validate` in `infra/`

**`terraform plan -var-file=environments/dev.tfvars`, before and after.** This
is AC-6 and the answer to whether Terraform will fight the deploy.

*Before* — an apply would have re-armed the trap:

```
  # google_cloud_run_v2_job.seed_portfolios will be updated in-place
      ~ image = "…/backend@sha256:854327a4…" -> "…/backend:latest"

Plan: 0 to add, 3 to change, 0 to destroy.
```

*After* — no job's image appears in the plan at all. The three jobs are still
listed, and the only thing each proposes is **adding the label**:

```
  # google_cloud_run_v2_job.purge_audit will be updated in-place
      ~ labels = {
          + "image-owner" = "delivery"
        }

Plan: 0 to add, 4 to change, 0 to destroy.
```

**Honestly: the plan is not empty, and two of the differences are not mine.**
Both before and after, `dev` also shows `client`/`client_version` metadata
being nulled (Cloud Run writes those when `gcloud` touches a resource) and the
service's `APP_RELEASE` reverting to `var.backend_release` — which `run.tf`
already documents as deliberate, since `traffic` is ignored and the revision an
apply creates never serves. Those exist on `develop` today, are outside this
spec, and are the reason the claim here is the narrow one: **no job's image is
in the plan after a CD run**, not "the plan is empty".

**Not run, and why it matters:**

- **A deploy.** `backend-cd` is a human's button (CLAUDE.md) and the brief is
  read-only against the cloud, so this change has **not** been exercised end to
  end. Everything above is a stubbed `gcloud`, a static grep and a plan. The
  first real run is the proof: afterwards all three jobs must report the
  service's digest.
- **`terraform apply`.** Consequence: **the label is not in the cloud yet.**
  Until dev is applied, `point_jobs_at_image` finds nothing and the deploy
  **fails by design** (case 12), naming `terraform apply`. That is the intended
  order — apply, then deploy — and it is a loud failure rather than a silent
  one, but it is a real precondition and §8 records it.
- **Staging and production.** Neither exists; the code is identical and
  unmeasured there.

## 8. Rollout

1. Merge.
2. `terraform apply -var-file=environments/dev.tfvars` on dev — one-time, adds
   the label to the three jobs. **Before** the next deploy, or that deploy
   fails at `point_jobs_at_image`.
3. Press *Run workflow* on `backend-cd` from `develop`.
4. Confirm: `gcloud run jobs list --region us-central1 --format='value(metadata.name, …image)'`
   shows all three jobs on the service's digest, and `terraform plan` proposes
   no image change.
