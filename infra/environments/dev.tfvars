# The proof-of-concept environment (specs/infra/0001-dev-environment.md).
#
# Read what is NOT here. There is no `domain` (no load balancer to certify), no
# `db_tier`, no `min_instances`/`max_instances` and no `log_retention_days`:
# every one of those is derived from `environment = "dev"` in infra/main.tf.
# That is deliberate — the cheap shape cannot be half-applied by forgetting a
# line here, and this file cannot make dev expensive.
project_id         = "finance-a2ui"
environment        = "dev"
backend_image      = "us-central1-docker.pkg.dev/finance-a2ui/finance-a2ui-dev/backend:latest"
auth_issuer        = "https://securetoken.google.com/finance-a2ui"
auth_audience      = "finance-a2ui"
auth_oidc_jwks_url = "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com"
# Firebase Hosting origins for both web clients — v0.9 (firebase.json) and the
# v1.0 client (frontend_v1/firebase.json, ADR-M D-9, port 3002 locally) — the local
# Flutter dev server, and the local static preview.
cors_allowed_origins  = "https://finance-a2ui.web.app,https://finance-a2ui.firebaseapp.com,http://localhost:8080,http://localhost:5173,https://finance-a2ui-v1.web.app,https://finance-a2ui-v1.firebaseapp.com,http://localhost:3002"
auth_bootstrap_admins = "lbertuzzi@somniosoftware.com"
# The preview is open on dev: anyone who can sign in with Google gets an
# account (spec backend/0040). Not a shortcut around the registry — the row
# is written and audited; a revoked account still stays revoked. Production
# and staging leave this at its `false` default.
auth_open_enrolment = true
alert_email         = "lbertuzzi@somniosoftware.com"
