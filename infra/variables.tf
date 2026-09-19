variable "project_id" {
  description = "GCP project that hosts this environment (one project per environment)."
  type        = string
}

variable "region" {
  description = "Primary region (data residency: docs/compliance/DATA_RESIDENCY_AND_TENANCY.md)."
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "staging | production — becomes ENVIRONMENT for the backend."
  type        = string
  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "environment must be staging or production."
  }
}

variable "backend_image" {
  description = "Fully qualified backend image (built by CI from backend/Dockerfile), e.g. us-central1-docker.pkg.dev/<project>/finance-a2ui/backend:<sha>."
  type        = string
}

variable "domain" {
  description = "Public hostname served by the HTTPS load balancer (managed certificate)."
  type        = string
}

variable "auth_issuer" {
  description = "OIDC issuer (AUTH_ISSUER), e.g. https://securetoken.google.com/<firebase-project>."
  type        = string
}

variable "auth_audience" {
  description = "Expected token audience (AUTH_AUDIENCE)."
  type        = string
}

variable "auth_oidc_jwks_url" {
  description = "JWKS endpoint of the identity provider (AUTH_OIDC_JWKS_URL)."
  type        = string
}

variable "cors_allowed_origins" {
  description = "Comma-separated browser origins allowed to call the API."
  type        = string
}

variable "alert_email" {
  description = "Notification channel for uptime / error-rate / auth-failure alerts (on-call, see INCIDENT_RESPONSE_PLAN.md)."
  type        = string
}

variable "db_tier" {
  description = "Cloud SQL machine tier."
  type        = string
  default     = "db-custom-1-3840"
}

variable "min_instances" {
  description = "Cloud Run minimum instances (>= 1 in production: BCP RTO)."
  type        = number
  default     = 1
}

variable "max_instances" {
  description = "Cloud Run maximum instances."
  type        = number
  default     = 4
}

variable "log_retention_days" {
  description = "Cloud Logging retention for the _Default bucket (CLOUD_SERVICES.md §4)."
  type        = number
  default     = 90
}

variable "secret_rotation_days" {
  description = "Rotation reminder period for every Secret Manager secret (ACCESS_CONTROL.md §3)."
  type        = number
  default     = 90
}
