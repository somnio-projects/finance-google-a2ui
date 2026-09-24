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
  description = "dev | staging | production — becomes ENVIRONMENT for the backend. `dev` is the throwaway proof-of-concept shape (specs/infra/0001-dev-environment.md): everything that costs money while idle is derived off from this one value."
  type        = string
  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "environment must be dev, staging or production."
  }
}

variable "github_repository" {
  description = "owner/repo allowed to federate into this project (spec 0007 AC-3). Any other repository is refused by the provider condition."
  type        = string
  default     = "somnio-projects/finance-google-a2ui"
}

variable "backend_release" {
  description = "Release identifier reported by GET /health (APP_RELEASE). The pipeline passes <version>+<git-sha>; Terraform alone deploys the packaged default."
  type        = string
  default     = ""
}

variable "backend_image" {
  description = "BOOTSTRAP image for the Cloud Run service and every Cloud Run job (built by CI from backend/Dockerfile), e.g. us-central1-docker.pkg.dev/<project>/finance-a2ui/backend:<sha>. It is read at CREATE time only: every resource that uses it declares `ignore_changes` on its image, because `deploy_cloud_run.sh` owns which build runs and Terraform owns the shape (spec infra/0004). A mutable tag here is therefore harmless after the first apply and a trap before it — dev names `:latest`, and until 2026-09-22 two jobs really did run whatever that happened to point at."
  type        = string
}

variable "seed_portfolio_owners" {
  description = "Demo audience for the `seed-portfolios` Cloud Run job (spec backend/0035): the e-mail addresses that are given the curated portfolio when a human runs it. An argument list rather than an environment variable so `gcloud run jobs execute --args=a@x,b@y` overrides it for a one-off, which is how it is normally used. EMPTY BY DEFAULT and deliberately so: spec 0035 OD-2 refuses to put a named person's address into an open-source repository, and an argument-less run fails loudly (the job's parser requires at least one address) rather than seeding somebody nobody chose. Nothing runs this job automatically."
  type        = list(string)
  default     = []
}

variable "domain" {
  description = "Public hostname served by the HTTPS load balancer (managed certificate). Required for staging and production; must be empty for dev, which has no load balancer and is reached on Cloud Run's own run.app URL."
  type        = string
  default     = ""
  validation {
    # Both directions on purpose: a staging/production apply without a domain
    # would fail late, at certificate creation, and a dev apply *with* one
    # would silently ignore it — there is nothing in dev to certify.
    condition     = var.environment == "dev" ? var.domain == "" : var.domain != ""
    error_message = "domain is required for staging and production (the managed certificate needs it) and must be empty for dev (no load balancer exists to serve it)."
  }
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

variable "auth_open_enrolment" {
  description = "Whether a verified SSO identity with no registry row enrols itself as an active member (AUTH_OPEN_ENROLMENT, spec backend/0040). FALSE by default and deliberately so: the sign-in screen says access is invite-only, and an environment that sets this true is saying the opposite. `revoked` and `requested` accounts are never enrolled either way — only the absence of a row."
  type        = bool
  default     = false
}

variable "auth_bootstrap_admins" {
  description = "Comma-separated e-mails made active admins at boot (AUTH_BOOTSTRAP_ADMINS, spec backend/0027 OD-2). A registry with no admin can never gain one through the API, so a fresh environment names its first admins here."
  type        = string
  default     = ""
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
  description = "Cloud SQL machine tier. Leave null to take the tier derived from the environment: the smallest shared-core tier in dev, `db-custom-1-3840` elsewhere (main.tf)."
  type        = string
  default     = null
}

variable "min_instances" {
  description = "Cloud Run minimum instances. Leave null to derive: 1 outside dev (BCP RTO), 0 in dev so an idle proof of concept bills nothing."
  type        = number
  default     = null
}

variable "max_instances" {
  description = "Cloud Run maximum instances. Leave null to derive: 4 outside dev, 2 in dev."
  type        = number
  default     = null
}

variable "log_retention_days" {
  description = "Cloud Logging retention for the _Default bucket (CLOUD_SERVICES.md §4). Leave null to derive: 90 days outside dev, 30 in dev (the free tier)."
  type        = number
  default     = null
}

variable "secret_rotation_days" {
  description = "Rotation reminder period for every Secret Manager secret (ACCESS_CONTROL.md §3)."
  type        = number
  default     = 90
}
