# The proof-of-concept environment (specs/infra/0001-dev-environment.md).
#
# Read what is NOT here. There is no `domain` (no load balancer to certify), no
# `db_tier`, no `min_instances`/`max_instances` and no `log_retention_days`:
# every one of those is derived from `environment = "dev"` in infra/main.tf.
# That is deliberate — the cheap shape cannot be half-applied by forgetting a
# line here, and this file cannot make dev expensive.
project_id           = "finance-a2ui"
environment          = "dev"
backend_image        = "us-central1-docker.pkg.dev/finance-a2ui/finance-a2ui-dev/backend:latest"
auth_issuer          = "https://securetoken.google.com/finance-a2ui"
auth_audience        = "finance-a2ui"
auth_oidc_jwks_url   = "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com"
cors_allowed_origins = "http://localhost:8080"
alert_email          = "lbertuzzi@somniosoftware.com"
