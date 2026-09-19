output "api_ip" {
  description = "Global anycast IP to point the DNS A record of var.domain at."
  value       = google_compute_global_address.api.address
}

output "cloud_run_service" {
  description = "Cloud Run service name (deploy target for CI)."
  value       = google_cloud_run_v2_service.backend.name
}

output "backend_service_account" {
  description = "Runtime identity of the API."
  value       = google_service_account.backend.email
}

output "sql_instance_connection_name" {
  description = "Cloud SQL instance connection name."
  value       = google_sql_database_instance.postgres.connection_name
}

output "secrets_to_populate" {
  description = "Secrets whose value the security owner adds out of band (never via Terraform)."
  value       = [for s in google_secret_manager_secret.external : s.secret_id]
}

output "artifact_registry_repository" {
  description = "Docker repository the delivery pipeline pushes to (spec 0007)."
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.backend.repository_id}"
}

output "wif_provider" {
  description = "Value for the GCP_WIF_PROVIDER repository variable used by google-github-actions/auth."
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "deployer_service_account" {
  description = "Value for the GCP_DEPLOYER_SA repository variable — the identity GitHub Actions impersonates."
  value       = google_service_account.deployer.email
}
