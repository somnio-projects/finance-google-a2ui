# Logging retention, control-plane audit logs, uptime check and alerting —
# the platform half of docs/compliance/CLOUD_SERVICES.md §4–5.
# SOC 2 CC7.2 F4/F6/F7 · ISO 27001 A.8.15, A.8.16.

resource "google_logging_project_bucket_config" "default" {
  project        = var.project_id
  location       = "global"
  bucket_id      = "_Default"
  retention_days = var.log_retention_days
}

# Data-access audit logs for the services that hold Confidential/Restricted data.
resource "google_project_iam_audit_config" "data_access" {
  for_each = toset(["sqladmin.googleapis.com", "secretmanager.googleapis.com", "run.googleapis.com"])
  project  = var.project_id
  service  = each.value

  audit_log_config {
    log_type = "ADMIN_READ"
  }
  audit_log_config {
    log_type = "DATA_READ"
  }
  audit_log_config {
    log_type = "DATA_WRITE"
  }
}

resource "google_monitoring_notification_channel" "oncall_email" {
  display_name = "${local.name} on-call"
  type         = "email"
  labels       = { email_address = var.alert_email }
}

resource "google_monitoring_uptime_check_config" "readyz" {
  display_name = "${local.name} /readyz"
  timeout      = "10s"
  period       = "60s"

  http_check {
    path         = "/readyz"
    port         = 443
    use_ssl      = true
    validate_ssl = true
  }

  monitored_resource {
    type   = "uptime_url"
    labels = { project_id = var.project_id, host = var.domain }
  }
}

resource "google_monitoring_alert_policy" "readyz_down" {
  display_name          = "${local.name}: readiness failing"
  combiner              = "OR"
  notification_channels = [google_monitoring_notification_channel.oncall_email.id]

  conditions {
    display_name = "uptime check failed"
    condition_threshold {
      filter          = "metric.type=\"monitoring.googleapis.com/uptime_check/check_passed\" AND resource.type=\"uptime_url\" AND metric.label.check_id=\"${google_monitoring_uptime_check_config.readyz.uptime_check_id}\""
      comparison      = "COMPARISON_GT"
      threshold_value = 1
      duration        = "180s"
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_NEXT_OLDER"
        cross_series_reducer = "REDUCE_COUNT_FALSE"
        group_by_fields      = ["resource.label.*"]
      }
    }
  }
  documentation {
    content = "Follow docs/compliance/INCIDENT_RESPONSE_PLAN.md — declare SEV-1 if the API is fully unavailable."
  }
}

resource "google_monitoring_alert_policy" "server_errors" {
  display_name          = "${local.name}: 5xx spike"
  combiner              = "OR"
  notification_channels = [google_monitoring_notification_channel.oncall_email.id]

  conditions {
    display_name = "more than 10 5xx responses in 5 minutes"
    condition_threshold {
      filter          = "metric.type=\"run.googleapis.com/request_count\" AND resource.type=\"cloud_run_revision\" AND resource.label.service_name=\"${google_cloud_run_v2_service.backend.name}\" AND metric.label.response_code_class=\"5xx\""
      comparison      = "COMPARISON_GT"
      threshold_value = 10
      duration        = "300s"
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_SUM"
      }
    }
  }
}

# Authentication failures are logged with their error code (auth/*); a spike
# means credential stuffing or a broken IdP.
resource "google_logging_metric" "auth_rejected" {
  name        = "${local.name}-auth-rejected"
  description = "Requests rejected with an auth/* problem code"
  filter      = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"${google_cloud_run_v2_service.backend.name}\" AND jsonPayload.code=~\"^auth/\""
  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
  }
}

resource "google_monitoring_alert_policy" "auth_failures" {
  display_name          = "${local.name}: authentication failure spike"
  combiner              = "OR"
  notification_channels = [google_monitoring_notification_channel.oncall_email.id]

  conditions {
    display_name = "more than 100 auth rejections in 5 minutes"
    condition_threshold {
      filter          = "metric.type=\"logging.googleapis.com/user/${google_logging_metric.auth_rejected.name}\" AND resource.type=\"cloud_run_revision\""
      comparison      = "COMPARISON_GT"
      threshold_value = 100
      duration        = "300s"
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_SUM"
      }
    }
  }
}
