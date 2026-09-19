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
