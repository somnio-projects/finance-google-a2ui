# Gemini spend: warn before the prepaid AI Studio balance runs out, and page
# the moment it has (specs/infra/0006, backend/0058).
#
# On 2026-11-13 the US$5 prepaid balance reached zero during a QA spike. From
# then on every generateContent answered HTTP 402 and the assistant stopped,
# and nothing had warned anyone. AI Studio exposes no balance API for a
# prepaid key, so the backend ESTIMATES each turn's cost from Gemini's own
# usageMetadata and its declared price table (backend/src/app/core/
# model_pricing.py) and writes it on the `agent.turn` log line. Everything
# here reads that line; nothing here can see the real balance — the 50 %/80 %
# alerts are a 24 h burn rate relative to var.gemini_credit_usd, not a balance.
#
# SOC 2 CC7.2 · ISO 27001 A.8.16 (monitoring), A1.1 (capacity).

locals {
  # The field values this file filters on. They are COPIES of Python
  # constants (agent_telemetry.COST_FIELD, model_errors.MODEL_OUT_OF_CREDIT),
  # and backend/tests/unit/core/test_spend_alert_contract.py fails the
  # backend gate if either side is renamed alone.
  gemini_cost_field    = "estimated_cost_usd"
  gemini_out_of_credit = "model-out-of-credit"
  # agent_telemetry.cost_fields's flag for a turn the price table cannot price.
  gemini_price_missing_field = "price_missing"
  gemini_turn_log_scope      = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"${google_cloud_run_v2_service.backend.name}\" AND jsonPayload.event=\"agent.turn\""

  # Fraction of var.gemini_credit_usd spent in a rolling 24 h → severity.
  gemini_spend_thresholds = {
    "50" = { fraction = 0.5, severity = "WARNING" }
    "80" = { fraction = 0.8, severity = "CRITICAL" }
  }

  # Email channels this file creates, plus Slack (or any other) channels a human
  # created in the console and Terraform only REFERENCES (specs/infra/0007).
  gemini_alert_channels = concat(
    [for channel in google_monitoring_notification_channel.spend_email : channel.id],
    var.spend_alert_channel_ids,
  )
  gemini_runbook = "Follow docs/gemini-balance-runbook.md: check usage in Google AI Studio, top up the prepaid balance, and enable auto-reload with a monthly cap."
}

# One channel per address. An empty list (the default) creates none, and the
# policies below still exist and still open incidents — they notify nobody.
# Slack is NOT created here: the OAuth token of the Google Cloud Monitoring app
# would have to live in git or in Terraform state. A human authorises it in the
# console and the channel's id goes in var.spend_alert_channel_ids.
resource "google_monitoring_notification_channel" "spend_email" {
  for_each     = toset(var.spend_alert_emails)
  display_name = "${local.name} Gemini spend"
  type         = "email"
  labels       = { email_address = each.value }
}

# A DISTRIBUTION, not a counter: a counter counts log entries and cannot add
# up a value, while a distribution keeps the sum of what it extracts — which
# PromQL reads back as `<metric>_sum`, so `increase(..._sum[24h])` is the
# estimated spend of the last 24 hours. Turns that billed nothing, and turns
# whose model has no price (`price_missing`), are filtered out rather than
# left for EXTRACT to fail on.
resource "google_logging_metric" "gemini_cost" {
  name            = "${local.name}-gemini-estimated-cost"
  description     = "Estimated Gemini cost per agent turn, in USD (backend spec 0058)"
  filter          = "${local.gemini_turn_log_scope} AND jsonPayload.model_calls_billed>0 AND jsonPayload.${local.gemini_price_missing_field}=false"
  value_extractor = "EXTRACT(jsonPayload.${local.gemini_cost_field})"

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "DISTRIBUTION"
    unit        = "USD"
  }

  bucket_options {
    exponential_buckets {
      num_finite_buckets = 20
      growth_factor      = 2
      scale              = 0.0001
    }
  }
}

resource "google_monitoring_alert_policy" "gemini_spend" {
  for_each              = local.gemini_spend_thresholds
  display_name          = "${local.name}: Gemini estimated spend over ${each.key}% of the credit in 24h"
  combiner              = "OR"
  severity              = each.value.severity
  notification_channels = local.gemini_alert_channels

  conditions {
    display_name = "rolling 24h estimated spend > ${each.value.fraction * var.gemini_credit_usd} USD"
    condition_prometheus_query_language {
      # Metric name: `logging.googleapis.com/user/<name>` with the first `/`
      # as `:` and every other non-word character as `_`.
      query               = "sum(increase(logging_googleapis_com:user_${replace(google_logging_metric.gemini_cost.name, "-", "_")}_sum{monitored_resource=\"cloud_run_revision\"}[24h])) > ${each.value.fraction * var.gemini_credit_usd}"
      duration            = "0s"
      evaluation_interval = "300s"
    }
  }

  documentation {
    content   = local.gemini_runbook
    mime_type = "text/markdown"
  }
}

# A turn billed tokens against a model the price table does not know: its
# cost is null, the metric above filters it out, and the spend alerts are
# blind to it. One line is enough to say the estimate is now incomplete.
resource "google_monitoring_alert_policy" "gemini_price_missing" {
  display_name          = "${local.name}: Gemini turn billed on an unpriced model"
  combiner              = "OR"
  severity              = "WARNING"
  notification_channels = local.gemini_alert_channels

  conditions {
    display_name = "an agent turn logged price_missing=true"
    condition_matched_log {
      filter = "${local.gemini_turn_log_scope} AND jsonPayload.${local.gemini_price_missing_field}=true"
    }
  }

  alert_strategy {
    notification_rate_limit {
      period = "3600s"
    }
    auto_close = "1800s"
  }

  documentation {
    content   = "GEMINI_MODEL names a model with no entry in backend/src/app/core/model_pricing.py, so its spend is not in the 50 %/80 % alerts. Add the model's prices from the AI Studio pricing page (docs/gemini-balance-runbook.md §1)."
    mime_type = "text/markdown"
  }
}

# The balance is already gone: a single `model-out-of-credit` turn is enough.
# A log-match condition fires on the entry itself, with no metric to wait for.
resource "google_monitoring_alert_policy" "gemini_out_of_credit" {
  display_name          = "${local.name}: Gemini credit exhausted (HTTP 402)"
  combiner              = "OR"
  severity              = "CRITICAL"
  notification_channels = local.gemini_alert_channels

  conditions {
    display_name = "an agent turn ended model-out-of-credit"
    condition_matched_log {
      filter = "${local.gemini_turn_log_scope} AND jsonPayload.outcome=\"${local.gemini_out_of_credit}\""
    }
  }

  alert_strategy {
    notification_rate_limit {
      period = "3600s"
    }
    auto_close = "1800s"
  }

  documentation {
    content   = local.gemini_runbook
    mime_type = "text/markdown"
  }
}
