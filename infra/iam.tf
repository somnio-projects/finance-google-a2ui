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
