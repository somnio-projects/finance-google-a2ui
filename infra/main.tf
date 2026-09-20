locals {
  name   = "finance-a2ui-${var.environment}"
  labels = { app = "finance-a2ui", environment = var.environment, managed-by = "terraform" }

  # ------------------------------------------------------------------ posture
  #
  # ONE fact about this environment, derived from its name, drives every
  # durability/exposure/cost decision below. It is deliberately not a variable:
  # a caller cannot make `dev` expensive, and cannot make `production` cheap, by
  # forgetting or mis-setting a flag. Read this block and you know what an
  # environment is — the resource files only consume it.
  #
  # Ephemeral == "a throwaway proof of concept": nothing in it is worth
  # restoring, nothing in it should bill while nobody is using it, and it must
  # be destroyable with `terraform destroy` on the day it stops being useful.
  # What that gives up is stated in specs/infra/0001-dev-environment.md §5 and
  # in docs/compliance/ — it is a smaller control set, not the same one.
  ephemeral = var.environment == "dev"

  # Durability (database.tf)
  db_availability     = local.ephemeral ? "ZONAL" : "REGIONAL" # a standby doubles the instance price
  db_point_in_time    = !local.ephemeral                       # PITR bills for retained write-ahead logs
  db_retained_backups = local.ephemeral ? 2 : 30
  db_log_retention    = local.db_point_in_time ? 7 : null # only meaningful with PITR on
  db_deletion_protect = !local.ephemeral                  # a POC you cannot destroy bills forever
  db_tier             = coalesce(var.db_tier, local.ephemeral ? "db-f1-micro" : "db-custom-1-3840")
  db_disk_type        = local.ephemeral ? "PD_HDD" : "PD_SSD"

  # Exposure (edge.tf, run.tf). No load balancer means no Cloud Armor, no
  # managed certificate, no reserved global IP and no fixed monthly forwarding
  # charge. The endpoint is Cloud Run's own run.app URL, which only resolves
  # because dev's ingress is open; every other environment stays LB-only.
  edge_enabled  = !local.ephemeral
  run_ingress   = local.ephemeral ? "INGRESS_TRAFFIC_ALL" : "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"
  min_instances = coalesce(var.min_instances, local.ephemeral ? 0 : 1)
  max_instances = coalesce(var.max_instances, local.ephemeral ? 2 : 4)

  # Observability (observability.tf). An external uptime check needs a hostname
  # that exists before the apply; in dev there is none, so the check and the
  # alert that depends on it are the two signals dev goes without. The 5xx and
  # auth-failure alerts are log-based, cost nothing, and stay.
  uptime_check_enabled = !local.ephemeral
  log_retention_days   = coalesce(var.log_retention_days, local.ephemeral ? 30 : 90)
  image_versions_kept  = local.ephemeral ? 5 : 20

  # Where the API answers. Outside dev that is the certified domain. In dev it
  # is Cloud Run's own deterministic URL, `<service>-<project number>.<region>.
  # run.app` — computed rather than read from the service, because reading
  # `google_cloud_run_v2_service.backend.uri` to build that service's own
  # environment would be a dependency cycle.
  #
  # This value is used for the agent card's self-link only. Nothing
  # load-bearing depends on the guess being right: dev's TRUSTED_HOSTS is the
  # wildcard the backend already permits outside production, and the address
  # the pipeline probes comes from the `public_url` output, which reads the
  # real `uri` after the apply.
  run_url         = "https://${local.name}-api-${data.google_project.this.number}.${var.region}.run.app"
  public_base_url = local.ephemeral ? local.run_url : "https://${var.domain}"
  trusted_hosts   = local.ephemeral ? "*" : var.domain

  required_apis = [
    "run.googleapis.com",
    "sqladmin.googleapis.com",
    "secretmanager.googleapis.com",
    "servicenetworking.googleapis.com",
    "vpcaccess.googleapis.com",
    "compute.googleapis.com",
    "cloudscheduler.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "pubsub.googleapis.com",
    "iam.googleapis.com",
    "artifactregistry.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
  ]
}

data "google_project" "this" {}

resource "google_project_service" "apis" {
  for_each           = toset(local.required_apis)
  service            = each.value
  disable_on_destroy = false
}
