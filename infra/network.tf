# Private network: the database has no public IP; Cloud Run reaches it through
# a Serverless VPC Access connector; ingress only via the load balancer.
# SOC 2 CC6.6 · ISO 27001 A.8.20, A.8.22.

resource "google_compute_network" "vpc" {
  name                    = "${local.name}-vpc"
  auto_create_subnetworks = false
  depends_on              = [google_project_service.apis]
}

resource "google_compute_subnetwork" "connector" {
  name    = "${local.name}-connector"
  region  = var.region
  network = google_compute_network.vpc.id

  # A Serverless VPC Access connector requires its own dedicated /28. Dev has
  # no connector (see below) and uses this subnet for Cloud Run's direct VPC
  # egress instead, which draws one address per running instance — Google's
  # sizing guidance for that is /26, and a subnet costs nothing either way.
  ip_cidr_range            = local.ephemeral ? "10.8.0.0/26" : "10.8.0.0/28"
  private_ip_google_access = true

  # Flow logs = edge/network access evidence (SOC 2 CC7.2 F5).
  log_config {
    aggregation_interval = "INTERVAL_5_MIN"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# Private services access range for Cloud SQL.
resource "google_compute_global_address" "private_services" {
  name          = "${local.name}-psa"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.id
}

resource "google_service_networking_connection" "private_services" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_services.name]
  depends_on              = [google_project_service.apis]
}

# A connector is a managed instance group: its floor is two e2-micro VMs that
# bill by the hour whether or not a request ever arrives — on its own, more
# than the whole rest of a dev environment. Dev therefore has none, and Cloud
# Run reaches the private database through direct VPC egress (run.tf), which
# has no standing compute. Staging and production keep the connector.
resource "google_vpc_access_connector" "run" {
  count  = local.ephemeral ? 0 : 1
  name   = "${local.name}-vpc-conn"
  region = var.region
  subnet {
    name = google_compute_subnetwork.connector.name
  }
  min_instances = 2
  max_instances = 3
  depends_on    = [google_project_service.apis]
}

# Deny everything inbound by default; nothing but the peered Cloud SQL range
# and Google health checks ever needs to talk inside this VPC.
resource "google_compute_firewall" "deny_all_ingress" {
  name      = "${local.name}-deny-all-ingress"
  network   = google_compute_network.vpc.id
  direction = "INGRESS"
  priority  = 65534
  deny {
    protocol = "all"
  }
  source_ranges = ["0.0.0.0/0"]
}
