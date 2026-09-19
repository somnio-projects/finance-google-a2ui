# Secret Manager — one secret per setting, regional replication, 90-day
# rotation reminders published to Pub/Sub (ACCESS_CONTROL.md §3, CLOUD_SERVICES.md §3).
# SOC 2 CC6.1 F8/F9 · ISO 27001 A.5.17, A.8.24.

resource "google_pubsub_topic" "secret_rotation" {
  name       = "${local.name}-secret-rotation"
  labels     = local.labels
  depends_on = [google_project_service.apis]
}

# Secret Manager's service agent must be able to publish rotation events.
resource "google_pubsub_topic_iam_member" "secret_manager_publisher" {
  topic  = google_pubsub_topic.secret_rotation.id
  role   = "roles/pubsub.publisher"
  member = "serviceAccount:service-${data.google_project.this.number}@gcp-sa-secretmanager.iam.gserviceaccount.com"
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
