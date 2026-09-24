# Continuous delivery: where images live and who is allowed to publish and
# deploy them (spec 0007, GGU-48). The pipeline authenticates with Workload
# Identity Federation — there is deliberately no service-account key resource
# in this repository, and adding one is a review blocker.
# SOC 2 CC6.1, CC6.3, CC8.1 · ISO 27001 A.5.15, A.8.4, A.8.32.

resource "google_artifact_registry_repository" "backend" {
  repository_id = local.name
  location      = var.region
  format        = "DOCKER"
  description   = "Backend runtime images, one immutable tag per commit."
  labels        = local.labels

  docker_config {
    # Tags may move (:develop, :main) but a digest never changes, and the
    # pipeline deploys by digest. Immutable tags would break the moving tags.
    immutable_tags = false
  }

  cleanup_policy_dry_run = false

  cleanup_policies {
    id     = "keep-recent-builds"
    action = "KEEP"
    most_recent_versions {
      keep_count = local.image_versions_kept
    }
  }

  cleanup_policies {
    id     = "delete-untagged-after-30-days"
    action = "DELETE"
    condition {
      tag_state  = "UNTAGGED"
      older_than = "2592000s"
    }
  }

  depends_on = [google_project_service.apis]
}

# ---------------------------------------------------------------- identity

resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "${local.name}-github"
  display_name              = "GitHub Actions (${var.environment})"
  description               = "Federated identity for this repository's delivery pipeline."
  depends_on                = [google_project_service.apis]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-oidc"
  display_name                       = "GitHub OIDC"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }

  # Without this condition the provider would mint credentials for ANY GitHub
  # repository that knows the pool name. It is the whole security of AC-3.
  #
  # Production additionally requires the token to come from `main`: the
  # repository condition alone would let a workflow on any branch — including
  # one added in a fork's pull request that can request `id-token: write` —
  # obtain a credential that deploys production.
  attribute_condition = (
    var.environment == "production"
    ? "assertion.repository == \"${var.github_repository}\" && assertion.ref == \"refs/heads/main\""
    : "assertion.repository == \"${var.github_repository}\""
  )

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account" "deployer" {
  account_id   = "${local.name}-deployer"
  display_name = "finance-a2ui delivery pipeline (GitHub Actions)"
  description  = "Pushes images and creates Cloud Run revisions. Cannot read secrets or the database."
}

# Only this repository's workflows may impersonate the deployer.
resource "google_service_account_iam_member" "deployer_workload_identity" {
  service_account_id = google_service_account.deployer.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repository}"
}

# Push images — scoped to this repository, never project-wide.
resource "google_artifact_registry_repository_iam_member" "deployer_writer" {
  repository = google_artifact_registry_repository.backend.name
  location   = var.region
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.deployer.email}"
}

# Create revisions and shift traffic on this service only.
resource "google_cloud_run_v2_service_iam_member" "deployer_developer" {
  name     = google_cloud_run_v2_service.backend.name
  location = var.region
  role     = "roles/run.developer"
  member   = "serviceAccount:${google_service_account.deployer.email}"
}

# Execute the migration job, and nothing else in the project.
#
# `deploy_cloud_run.sh` runs `gcloud run jobs execute` **between** creating the
# no-traffic revision and shifting traffic to it, so the schema moves under a
# revision nobody is served yet. The grant above is scoped to the *service*, so
# the deployer could create that revision and then could not run the job:
#
#   PERMISSION_DENIED: Permission 'run.jobs.get' denied on resource
#   'namespaces/finance-a2ui/jobs/finance-a2ui-dev-migrate'
#
# The pipeline behaved correctly — it reported "migrations failed; the schema
# was not moved" and rolled traffic back — but no deploy could ever have
# succeeded. `run.developer` rather than `run.invoker` because the script polls
# the execution, which needs `run.jobs.get` as well as `run.jobs.run`.
# **Every delivery-owned job, not just the migration.** Spec `infra/0004` made
# the deploy pin all three jobs to the released digest, and this grant did not
# follow: the deployer could `list` nothing and `update` only `migrate`. The
# first real deploy after it failed at the guard, which reported *"no Cloud
# Run job carries image-owner=delivery"* and told the operator to run
# `terraform apply` — Terraform had already run, and the labels were there.
# The suite could not have caught it: it stubs `gcloud`, so it never meets an
# IAM decision (spec `infra/0005`).
#
# Per job rather than project-wide, which keeps what the original grant was
# for: the deployer still cannot touch a job nobody opted in. `for_each` over
# the same declaration the deploy filters on, so a fourth job is opted in once
# — in its own resource block — and is reachable and pinnable by construction.
resource "google_cloud_run_v2_job_iam_member" "deployer_owns_delivery_jobs" {
  for_each = {
    migrate         = google_cloud_run_v2_job.migrate.name
    purge_audit     = google_cloud_run_v2_job.purge_audit.name
    seed_portfolios = google_cloud_run_v2_job.seed_portfolios.name
    provision_users = google_cloud_run_v2_job.provision_users.name
  }

  name     = each.value
  location = var.region
  role     = "roles/run.developer"
  member   = "serviceAccount:${google_service_account.deployer.email}"
}

# Listing jobs is a **project-level** permission: there is no per-job grant
# that makes a job appear in `gcloud run jobs list`. `roles/run.viewer` is the
# smallest role that carries `run.jobs.list`, and it is read-only — the write
# path stays the per-job grants above.
resource "google_project_iam_member" "deployer_lists_jobs" {
  project = var.project_id
  role    = "roles/run.viewer"
  member  = "serviceAccount:${google_service_account.deployer.email}"
}

# Publish the A2UI client's bundle to Firebase Hosting (spec frontend/0017).
#
# PROJECT-SCOPED, and that is a real widening worth naming rather than
# burying: every other grant above is on one resource — this repository's
# Artifact Registry repository, this service, this job — because Google offers
# resource-level IAM for them. Firebase Hosting does not. There are no
# per-site IAM bindings, so `roles/firebasehosting.admin` on the project is
# the narrowest role that can deploy a site, and it can deploy, delete and
# roll back every site in the project.
#
# What bounds it is the identity, not the role: this service account is
# impersonable only through the Workload Identity pool, only from
# `var.github_repository`, and on production only from `refs/heads/main`
# (the attribute condition above). `test_wif_conditions.sh` fails the build if
# that narrowing is ever removed.
#
# Not `roles/firebase.admin`, which is the whole product — Firestore, Auth
# configuration, the lot — and would let the deployer change who may sign in.
resource "google_project_iam_member" "deployer_hosting" {
  project = data.google_project.this.project_id
  role    = "roles/firebasehosting.admin"
  member  = "serviceAccount:${google_service_account.deployer.email}"
}

# Deploy a revision that RUNS AS the backend identity, without being able to
# act as any other service account in the project.
resource "google_service_account_iam_member" "deployer_acts_as_backend" {
  service_account_id = google_service_account.backend.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.deployer.email}"
}
