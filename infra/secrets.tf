# Secret Manager — one secret per setting, regional replication, 90-day
# rotation reminders published to Pub/Sub (ACCESS_CONTROL.md §3, CLOUD_SERVICES.md §3).
# SOC 2 CC6.1 F8/F9 · ISO 27001 A.5.17, A.8.24.

resource "google_pubsub_topic" "secret_rotation" {
  name       = "${local.name}-secret-rotation"
  labels     = local.labels
  depends_on = [google_project_service.apis]
}

# Secret Manager's service agent must be able to publish rotation events — but
# it does not exist until something asks for it. Enabling the API is not enough,
# and granting a role to an identity that has not been created fails with
#
#   Service account service-<n>@gcp-sa-secretmanager.iam.gserviceaccount.com
#   does not exist.
#
# which is what the first dev apply hit. Creating it explicitly also removes the
# implicit dependency: the member below now references a resource, so Terraform
# orders the two instead of racing them.
resource "google_project_service_identity" "secret_manager" {
  provider = google-beta
  service  = "secretmanager.googleapis.com"

  depends_on = [google_project_service.apis]
}

# The resource above returns as soon as the agent is *requested*, and IAM does
# not see it for a few seconds afterwards — so the grant below failed with
# "does not exist" even on the apply that had just created it. Ordering alone
# cannot fix that; the dependency was already correct. Granting the same role
# by hand a minute later succeeded, which is what identifies this as
# propagation rather than a missing identity.
#
# A fresh project is the only place this bites, and it is exactly where it
# hurts most: the first apply of a new environment. An apply that needs a
# manual re-run is a broken "reproducible deploy" (GGU-29 AC-4), so the wait
# is in the configuration rather than in a runbook step someone has to know.
resource "time_sleep" "secret_manager_identity_propagation" {
  depends_on      = [google_project_service_identity.secret_manager]
  create_duration = "30s"
}

resource "google_pubsub_topic_iam_member" "secret_manager_publisher" {
  topic  = google_pubsub_topic.secret_rotation.id
  role   = "roles/pubsub.publisher"
  member = "serviceAccount:${google_project_service_identity.secret_manager.email}"

  depends_on = [time_sleep.secret_manager_identity_propagation]
}

locals {
  # Values for these are set out of band by the security owner (never in
  # Terraform state): the model key and the Sentry DSN.
  external_secrets = toset(["SENTRY_DSN", "GEMINI_API_KEY"])
  rotation_period  = "${var.secret_rotation_days * 24 * 3600}s"
}

resource "google_secret_manager_secret" "external" {
  for_each  = local.external_secrets
  secret_id = "${local.name}-${lower(replace(each.value, "_", "-"))}"
  labels    = local.labels

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }

  topics {
    name = google_pubsub_topic.secret_rotation.id
  }
  rotation {
    rotation_period    = local.rotation_period
    next_rotation_time = timeadd(timestamp(), local.rotation_period)
  }

  lifecycle {
    ignore_changes = [rotation[0].next_rotation_time]
  }
  depends_on = [google_pubsub_topic_iam_member.secret_manager_publisher]
}

resource "google_secret_manager_secret" "database_url" {
  secret_id = "${local.name}-database-url"
  labels    = local.labels
  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
  topics {
    name = google_pubsub_topic.secret_rotation.id
  }
  rotation {
    rotation_period    = local.rotation_period
    next_rotation_time = timeadd(timestamp(), local.rotation_period)
  }
  lifecycle {
    ignore_changes = [rotation[0].next_rotation_time]
  }
  depends_on = [google_pubsub_topic_iam_member.secret_manager_publisher]
}

resource "google_secret_manager_secret_version" "database_url" {
  secret = google_secret_manager_secret.database_url.id
  secret_data = format(
    "postgresql+asyncpg://%s:%s@%s:5432/%s",
    google_sql_user.app.name,
    random_password.db_app.result,
    google_sql_database_instance.postgres.private_ip_address,
    google_sql_database.finance.name,
  )
}

resource "random_password" "auth_jwt_secret" {
  length  = 64
  special = false
}

resource "google_secret_manager_secret" "auth_jwt_secret" {
  secret_id = "${local.name}-auth-jwt-secret"
  labels    = local.labels
  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
  topics {
    name = google_pubsub_topic.secret_rotation.id
  }
  rotation {
    rotation_period    = local.rotation_period
    next_rotation_time = timeadd(timestamp(), local.rotation_period)
  }
  lifecycle {
    ignore_changes = [rotation[0].next_rotation_time]
  }
  depends_on = [google_pubsub_topic_iam_member.secret_manager_publisher]
}

resource "google_secret_manager_secret_version" "auth_jwt_secret" {
  secret      = google_secret_manager_secret.auth_jwt_secret.id
  secret_data = random_password.auth_jwt_secret.result
}
