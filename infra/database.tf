# Cloud SQL for PostgreSQL 16 — private IP only, TLS required, encryption at
# rest with Google-managed keys (decision in DATA_RESIDENCY_AND_TENANCY.md §3).
# SOC 2 A1.2, C1.1 · ISO 27001 A.8.13, A.8.14, A.8.24.
#
# Redundancy and recoverability are the expensive half and are derived from
# `local.ephemeral` (main.tf): staging and production keep regional HA, PITR,
# 30 retained backups and deletion protection; dev keeps none of them, and
# says so in specs/infra/0001-dev-environment.md §5 and
# docs/compliance/BACKUP_AND_RECOVERY.md. Everything that protects the *data
# in flight* — private IP, no public IP, TLS-only, connection logging — is
# identical in every environment, because none of it costs anything.

resource "google_sql_database_instance" "postgres" {
  name                = "${local.name}-pg"
  database_version    = "POSTGRES_16"
  region              = var.region
  deletion_protection = local.db_deletion_protect
  depends_on          = [google_service_networking_connection.private_services]

  settings {
    tier              = local.db_tier
    availability_type = local.db_availability # REGIONAL = synchronous standby in another zone (BCP §5)
    disk_type         = local.db_disk_type
    disk_autoresize   = true
    user_labels       = local.labels

    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.vpc.id
      ssl_mode        = "ENCRYPTED_ONLY"
    }

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = local.db_point_in_time # RPO 1 h target → minutes in practice
      start_time                     = "03:00"
      transaction_log_retention_days = local.db_log_retention
      backup_retention_settings {
        retained_backups = local.db_retained_backups # BACKUP_AND_RECOVERY.md §2
        retention_unit   = "COUNT"
      }
    }

    maintenance_window {
      day          = 7
      hour         = 4
      update_track = "stable"
    }

    insights_config {
      query_insights_enabled  = true
      record_application_tags = false
      record_client_address   = false
    }

    database_flags {
      name  = "log_connections"
      value = "on"
    }
    database_flags {
      name  = "log_disconnections"
      value = "on"
    }
    database_flags {
      name  = "log_min_duration_statement"
      value = "1000"
    }
  }
}

resource "google_sql_database" "finance" {
  name     = "finance"
  instance = google_sql_database_instance.postgres.name
}

resource "random_password" "db_app" {
  length  = 32
  special = false
}

resource "google_sql_user" "app" {
  name     = "app"
  instance = google_sql_database_instance.postgres.name
  password = random_password.db_app.result
}
