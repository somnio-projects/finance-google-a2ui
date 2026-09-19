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
      keep_count = 20
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

# Deploy a revision that RUNS AS the backend identity, without being able to
# act as any other service account in the project.
resource "google_service_account_iam_member" "deployer_acts_as_backend" {
  service_account_id = google_service_account.backend.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.deployer.email}"
}
