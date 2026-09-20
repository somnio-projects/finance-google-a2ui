# Least-privilege identities (ACCESS_CONTROL.md §4). No human roles here:
# humans get viewer + time-boxed break-glass through the console/IAM Conditions.
# SOC 2 CC6.1, CC6.3 · ISO 27001 A.5.15, A.5.18, A.8.2.

resource "google_service_account" "backend" {
  account_id   = "${local.name}-run"
  display_name = "finance-a2ui backend (Cloud Run runtime)"
}

resource "google_project_iam_member" "backend_roles" {
  for_each = toset([
    "roles/cloudsql.client",
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/cloudtrace.agent",
  ])
  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.backend.email}"
}

locals {
  backend_secret_ids = merge(
    { for k, s in google_secret_manager_secret.external : k => s.secret_id },
    {
      DATABASE_URL    = google_secret_manager_secret.database_url.secret_id
      AUTH_JWT_SECRET = google_secret_manager_secret.auth_jwt_secret.secret_id
    },
  )
}

# Access is granted per secret, never project-wide.
resource "google_secret_manager_secret_iam_member" "backend_accessor" {
  for_each  = local.backend_secret_ids
  secret_id = each.value
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.backend.email}"
}

# Cloud Scheduler identity that may only start the retention job.
resource "google_service_account" "scheduler" {
  account_id   = "${local.name}-scheduler"
  display_name = "finance-a2ui scheduler (runs the audit purge job)"
}

resource "google_cloud_run_v2_job_iam_member" "scheduler_invokes_purge" {
  name     = google_cloud_run_v2_job.purge_audit.name
  location = var.region
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.scheduler.email}"
}

# Who may invoke the API service.
#
# There was no such binding at all, so the deployed service answers 403 to
# every caller without a Google identity — including on `/health`, which
# GGU-29 AC-1 requires to be green *on the public URL*. The delivery pipeline
# probes that URL as well (`infra/scripts/deploy_cloud_run.sh`), so this is not
# only a demo problem: the verify-before-shifting-traffic step could not have
# passed either.
#
# `allUsers` here does not mean "the API is open". Cloud Run invocation is the
# outer door; the application still requires a bearer token on every route
# except the handful listed in `tests/unit/api/test_openapi_contract.py::PUBLIC`,
# and the per-principal rate limiter and the security headers are unchanged.
# What this grants is the right to *reach* the service — which in dev is the
# entire point: there is no load balancer, the endpoint is the run.app URL, and
# a reviewer holding no Google identity has to be able to open it.
#
# Scoped to dev deliberately. Staging and production are
# `INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER`, and a serverless NEG behind the
# HTTPS load balancer is *expected* to need the same binding, with ingress
# rather than IAM as the network control. Expected, not verified: neither
# environment has ever been applied. Recorded in
# specs/infra/0001-dev-environment.md §11 to be confirmed at their first apply
# instead of guessed at here.
resource "google_cloud_run_v2_service_iam_member" "public_invoker" {
  count = local.ephemeral ? 1 : 0

  name     = google_cloud_run_v2_service.backend.name
  location = var.region
  role     = "roles/run.invoker"
  member   = "allUsers"
}
