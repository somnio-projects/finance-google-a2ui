# Cloud Run v2 service (the API) and the monthly retention job.
# Ingress only from the load balancer; egress only to private ranges (Cloud SQL)
# plus Google APIs; secrets mounted from Secret Manager; probes on the health
# routes. SOC 2 CC6.6, CC7.2, A1.2 · ISO 27001 A.8.9, A.8.16, A.8.31.
#
# Two things differ in dev (derived from `local.ephemeral`, main.tf): ingress is
# open, because there is no load balancer to be internal to, and the private
# database is reached through direct VPC egress rather than a connector whose
# two VMs would bill around the clock. Egress stays PRIVATE_RANGES_ONLY either
# way, so the database is still only reachable from inside the VPC.

locals {
  backend_env = {
    ENVIRONMENT          = var.environment
    APP_RELEASE          = var.backend_release
    LOG_LEVEL            = "INFO"
    PUBLIC_BASE_URL      = local.public_base_url
    CORS_ALLOWED_ORIGINS = var.cors_allowed_origins
    # The backend refuses the wildcard when ENVIRONMENT=production and permits
    # it elsewhere (core/config.py). Dev takes it because the run.app hostname
    # is not known until after the apply; staging and production name theirs.
    TRUSTED_HOSTS             = local.trusted_hosts
    AUTH_PROVIDER             = "oidc"
    AUTH_ISSUER               = var.auth_issuer
    AUTH_AUDIENCE             = var.auth_audience
    AUTH_OIDC_JWKS_URL        = var.auth_oidc_jwks_url
    AUTH_BOOTSTRAP_ADMINS     = var.auth_bootstrap_admins
    AUTH_OPEN_ENROLMENT       = tostring(var.auth_open_enrolment)
    AUTH_ADMIN_REQUIRE_MFA    = "true"
    AUDIT_RETENTION_DAYS      = "400"
    RUN_MIGRATIONS            = "true"
    FORWARDED_ALLOW_IPS       = "*" # Cloud Run's proxy sets X-Forwarded-For
    SENTRY_TRACES_SAMPLE_RATE = var.environment == "production" ? "0.1" : "0.0"
  }
  backend_secret_env = {
    DATABASE_URL    = google_secret_manager_secret.database_url.secret_id
    AUTH_JWT_SECRET = google_secret_manager_secret.auth_jwt_secret.secret_id
    SENTRY_DSN      = google_secret_manager_secret.external["SENTRY_DSN"].secret_id
    # Unset in the container = the scripted assistant (spec backend/0033); the
    # secret's value is set out of band by the security owner (secrets.tf).
    GEMINI_API_KEY = google_secret_manager_secret.external["GEMINI_API_KEY"].secret_id
  }

  # The declaration that `deploy_cloud_run.sh` reads. Every Cloud Run job below
  # carries it, and the deploy lists jobs by this label and points each one at
  # the digest it just released — so adding a fourth job means adding this line
  # and nothing else. There is no list of job names in the pipeline to forget.
  #
  # A label rather than a name prefix on purpose (spec infra/0004 OD-1): a
  # prefix derives the set from whatever happens to be deployed, which is how a
  # job nobody meant to touch gets updated. This derives it from a declaration
  # that lives in the same resource block as the job it opts in.
  delivery_owned_labels = merge(local.labels, { "image-owner" = "delivery" })
}

resource "google_cloud_run_v2_service" "backend" {
  name                = "${local.name}-api"
  location            = var.region
  ingress             = local.run_ingress
  deletion_protection = var.environment == "production"
  labels              = local.labels
  depends_on          = [google_secret_manager_secret_iam_member.backend_accessor]

  # Two systems touch this service and they own different fields. Terraform
  # owns the shape (identity, scaling, networking, secrets, probes); the
  # delivery pipeline owns WHICH image runs and WHERE traffic points
  # (spec 0007). Without this, the next `terraform apply` would re-point 100 %
  # of traffic at the newest revision — undoing a rollback the pipeline had
  # just performed — and revert the image to `var.backend_image`.
  #
  # `APP_RELEASE` is deliberately NOT ignored: an apply may create a revision
  # carrying the placeholder release, but because `traffic` is ignored that
  # revision never serves, and the next deploy supersedes it.
  lifecycle {
    ignore_changes = [
      template[0].containers[0].image,
      traffic,
    ]
  }

  template {
    service_account = google_service_account.backend.email
    labels          = local.labels

    scaling {
      min_instance_count = local.min_instances
      max_instance_count = local.max_instances
    }

    # `one()` rather than a conditional: the connector's count is 0 in dev, so
    # this is null there and the network_interfaces block below takes over.
    vpc_access {
      connector = one(google_vpc_access_connector.run[*].id)
      egress    = "PRIVATE_RANGES_ONLY"

      dynamic "network_interfaces" {
        for_each = local.ephemeral ? [1] : []
        content {
          network    = google_compute_network.vpc.id
          subnetwork = google_compute_subnetwork.connector.id
        }
      }
    }

    containers {
      image = var.backend_image

      ports {
        container_port = 8000
      }

      resources {
        limits            = { cpu = "1", memory = "512Mi" }
        cpu_idle          = true
        startup_cpu_boost = true
      }

      dynamic "env" {
        for_each = local.backend_env
        content {
          name  = env.key
          value = env.value
        }
      }

      dynamic "env" {
        for_each = local.backend_secret_env
        content {
          name = env.key
          value_source {
            secret_key_ref {
              secret  = env.value
              version = "latest"
            }
          }
        }
      }

      startup_probe {
        http_get {
          path = "/readyz"
          port = 8000
        }
        initial_delay_seconds = 5
        period_seconds        = 5
        failure_threshold     = 12
      }

      liveness_probe {
        http_get {
          path = "/health"
          port = 8000
        }
        period_seconds = 30
      }
    }
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }
}

# Schema migrations (spec 0020 §4.3). Same image, same secrets, no HTTP
# surface — the only way the schema ever changes (`security.md`: migrations are
# the only schema path; no `create_all` outside tests).
#
# **This did not exist until 2026-09-20, and nothing else ran migrations
# either** — not the pipeline, not Terraform, not the container. The database
# had the application pointed at it and none of its tables. `/readyz` passed
# the whole time because it proves the connection, not the schema, so the gap
# was invisible until the portfolio stopped living in process memory and
# actually needed a table to read.
#
# A job rather than a startup hook on purpose: two instances booting together
# would race each other through the same migration, and Alembic's version
# table is not a lock. `deploy_cloud_run.sh` executes this once and waits for
# it **before** a revision takes traffic, so no request ever reaches a schema
# that is half-applied.
resource "google_cloud_run_v2_job" "migrate" {
  name                = "${local.name}-migrate"
  location            = var.region
  deletion_protection = false
  labels              = local.delivery_owned_labels
  depends_on          = [google_secret_manager_secret_iam_member.backend_accessor]

  template {
    template {
      service_account = google_service_account.backend.email
      max_retries     = 0 # a failed migration is read, not retried blindly
      timeout         = "600s"

      vpc_access {
        connector = one(google_vpc_access_connector.run[*].id)
        egress    = "PRIVATE_RANGES_ONLY"

        dynamic "network_interfaces" {
          for_each = local.ephemeral ? [1] : []
          content {
            network    = google_compute_network.vpc.id
            subnetwork = google_compute_subnetwork.connector.id
          }
        }
      }

      containers {
        image   = var.backend_image
        command = ["alembic", "upgrade", "head"]

        dynamic "env" {
          for_each = { for k, v in local.backend_env : k => v if k != "RUN_MIGRATIONS" }
          content {
            name  = env.key
            value = env.value
          }
        }

        dynamic "env" {
          for_each = local.backend_secret_env
          content {
            name = env.key
            value_source {
              secret_key_ref {
                secret  = env.value
                version = "latest"
              }
            }
          }
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [template[0].template[0].containers[0].image]
  }
}

# Monthly audit-trail retention purge (DATA_RETENTION.md §2) — same image,
# same secrets, no HTTP surface.
#
# Cloud Scheduler runs this one, unattended, at 03:00 on the 1st. That is what
# made it the worst of the three to leave on `var.backend_image`: measured on
# 2026-09-22, this job was still carrying the **floating tag**
# `…/backend:latest`, resolving to a digest (`sha256:03073e2a…`) that was
# neither the running service's nor anything a pipeline had pushed. A monthly
# job deleting rows from `audit_events` with code nobody chose is a compliance
# statement that is not true. It carries `local.delivery_owned_labels` like the
# other two, so the deploy pins it to the released digest even though it never
# executes it (spec infra/0004).
resource "google_cloud_run_v2_job" "purge_audit" {
  name                = "${local.name}-purge-audit"
  location            = var.region
  deletion_protection = false
  labels              = local.delivery_owned_labels
  depends_on          = [google_secret_manager_secret_iam_member.backend_accessor]

  template {
    template {
      service_account = google_service_account.backend.email
      max_retries     = 1
      timeout         = "600s"

      vpc_access {
        connector = one(google_vpc_access_connector.run[*].id)
        egress    = "PRIVATE_RANGES_ONLY"

        dynamic "network_interfaces" {
          for_each = local.ephemeral ? [1] : []
          content {
            network    = google_compute_network.vpc.id
            subnetwork = google_compute_subnetwork.connector.id
          }
        }
      }

      containers {
        image   = var.backend_image
        command = ["python", "-m", "app.jobs.purge_audit"]

        dynamic "env" {
          for_each = { for k, v in local.backend_env : k => v if k != "RUN_MIGRATIONS" }
          content {
            name  = env.key
            value = env.value
          }
        }

        dynamic "env" {
          for_each = local.backend_secret_env
          content {
            name = env.key
            value_source {
              secret_key_ref {
                secret  = env.value
                version = "latest"
              }
            }
          }
        }
      }
    }
  }

  # The deploy owns the image; Terraform must not take it back. Without this,
  # the next `terraform apply` after a release re-points the job at
  # `var.backend_image` — which is the floating tag above — and the drift the
  # deploy just closed reopens with no deploy involved.
  lifecycle {
    ignore_changes = [template[0].template[0].containers[0].image]
  }
}

resource "google_cloud_scheduler_job" "purge_audit_monthly" {
  name        = "${local.name}-purge-audit-monthly"
  description = "Runs the audit_events retention purge (docs/compliance/DATA_RETENTION.md)."
  schedule    = "0 3 1 * *" # 03:00 UTC on the 1st
  time_zone   = "Etc/UTC"
  region      = var.region
  depends_on  = [google_project_service.apis]

  http_target {
    http_method = "POST"
    uri         = "https://${var.region}-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/${var.project_id}/jobs/${google_cloud_run_v2_job.purge_audit.name}:run"
    oauth_token {
      service_account_email = google_service_account.scheduler.email
    }
  }
}

# The demo audience (spec `backend/0035` §4.1). A **human-run** job, on
# purpose: `deploy_cloud_run.sh` does not execute it and no scheduler points
# at it, because deciding who gets a portfolio is not something a deploy
# should do on its own. `var.seed_portfolio_owners` is the list this
# environment is created with; `gcloud run jobs execute ... --args=...`
# overrides it for a one-off, which is the whole reason the addresses are
# `args` and not an environment variable.
#
# The job is safe to re-run: an owner who already has a portfolio is skipped
# unless `--reset` is passed (`app/jobs/seed_portfolios.py`).
#
# **The deploy pins this job's image; it still never runs it.** Those are two
# separate claims and only the second one is about seeding. This block used to
# reason the opposite way: no `ignore_changes`, so that Terraform rather than
# the pipeline would keep the image current, "because nothing updates this
# job's image". What Terraform actually kept it at was `var.backend_image` —
# the floating tag — and on 2026-09-22 a human run of it answered
#
#     No module named app.jobs.seed_portfolios
#
# from an image that predated the commit adding that entry point. Freezing at
# the applied image and floating on a mutable tag are the same defect wearing
# different clothes: in both, the build that runs is not the build that was
# released. The fix is an owner, which `migrate` already had — so this job
# carries `local.delivery_owned_labels` and the deploy points it at the
# released digest, and `ignore_changes` below keeps `terraform apply` from
# reverting that (spec infra/0004).
#
# `infra/scripts/tests/test_dev_environment.sh` still asserts the deploy script
# never names this job, and that assertion is now doing more work than it was:
# the deploy reaches it through the label, so there is nothing for a pipeline
# author to accidentally `execute`. Deciding who gets a portfolio stays a
# human's command.
resource "google_cloud_run_v2_job" "seed_portfolios" {
  name                = "${local.name}-seed-portfolios"
  location            = var.region
  deletion_protection = false
  labels              = local.delivery_owned_labels
  depends_on          = [google_secret_manager_secret_iam_member.backend_accessor]

  template {
    template {
      service_account = google_service_account.backend.email
      max_retries     = 0 # seeding twice is safe; a blind retry still tells nobody
      timeout         = "600s"

      vpc_access {
        connector = one(google_vpc_access_connector.run[*].id)
        egress    = "PRIVATE_RANGES_ONLY"

        dynamic "network_interfaces" {
          for_each = local.ephemeral ? [1] : []
          content {
            network    = google_compute_network.vpc.id
            subnetwork = google_compute_subnetwork.connector.id
          }
        }
      }

      containers {
        image   = var.backend_image
        command = ["python", "-m", "app.jobs.seed_portfolios"]
        args    = var.seed_portfolio_owners

        dynamic "env" {
          for_each = { for k, v in local.backend_env : k => v if k != "RUN_MIGRATIONS" }
          content {
            name  = env.key
            value = env.value
          }
        }

        dynamic "env" {
          for_each = local.backend_secret_env
          content {
            name = env.key
            value_source {
              secret_key_ref {
                secret  = env.value
                version = "latest"
              }
            }
          }
        }
      }
    }
  }

  # The deploy owns the image; Terraform must not take it back. Measured
  # before this block existed, `terraform plan` on dev read:
  #
  #   ~ image = "…/backend@sha256:854327a4…" -> "…/backend:latest"
  #
  # i.e. an apply would have undone a hand-fix applied hours earlier and
  # re-armed the trap. See spec infra/0004 §4.
  lifecycle {
    ignore_changes = [template[0].template[0].containers[0].image]
  }
}
