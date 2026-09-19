# Public edge: global external HTTPS load balancer with a Google-managed
# certificate, Cloud Armor (OWASP preconfigured WAF + rate limiting + adaptive
# DDoS protection) in front of the Cloud Run serverless NEG, HTTP→HTTPS redirect.
# SOC 2 CC6.6 F2 · ISO 27001 A.8.20, A.8.21, A.8.23.

resource "google_compute_security_policy" "waf" {
  name        = "${local.name}-waf"
  description = "Cloud Armor policy for the finance-a2ui API"
  type        = "CLOUD_ARMOR"

  adaptive_protection_config {
    layer_7_ddos_defense_config {
      enable = true
    }
  }

  rule {
    priority    = 1000
    action      = "deny(403)"
    description = "OWASP CRS: SQL injection"
    match {
      expr {
        expression = "evaluatePreconfiguredWaf('sqli-v33-stable', {'sensitivity': 1})"
      }
    }
  }

  rule {
    priority    = 1001
    action      = "deny(403)"
    description = "OWASP CRS: cross-site scripting"
    match {
      expr {
        expression = "evaluatePreconfiguredWaf('xss-v33-stable', {'sensitivity': 1})"
      }
    }
  }

  rule {
    priority    = 1002
    action      = "deny(403)"
    description = "OWASP CRS: remote code execution / local file inclusion"
    match {
      expr {
        expression = "evaluatePreconfiguredWaf('rce-v33-stable', {'sensitivity': 1}) || evaluatePreconfiguredWaf('lfi-v33-stable', {'sensitivity': 1})"
      }
    }
  }

  # Edge rate limit per client IP, ahead of the application limiter (120/min per token).
  rule {
    priority    = 2000
    action      = "throttle"
    description = "Per-IP rate limit"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    rate_limit_options {
      conform_action = "allow"
      exceed_action  = "deny(429)"
      enforce_on_key = "IP"
      rate_limit_threshold {
        count        = 300
        interval_sec = 60
      }
    }
  }

  rule {
    priority    = 2147483647
    action      = "allow"
    description = "default allow"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
  }
}

resource "google_compute_region_network_endpoint_group" "backend" {
  name                  = "${local.name}-neg"
  region                = var.region
  network_endpoint_type = "SERVERLESS"
  cloud_run {
    service = google_cloud_run_v2_service.backend.name
  }
}

resource "google_compute_backend_service" "backend" {
  name                  = "${local.name}-backend"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  protocol              = "HTTPS"
  security_policy       = google_compute_security_policy.waf.id

  backend {
    group = google_compute_region_network_endpoint_group.backend.id
  }

  # Edge access logs (SOC 2 CC7.2 F5), retained with the log bucket (90 days).
  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

resource "google_compute_url_map" "https" {
  name            = "${local.name}-https"
  default_service = google_compute_backend_service.backend.id
}

resource "google_compute_managed_ssl_certificate" "api" {
  name = "${local.name}-cert"
  managed {
    domains = [var.domain]
  }
}

resource "google_compute_ssl_policy" "modern" {
  name            = "${local.name}-tls"
  profile         = "MODERN"
  min_tls_version = "TLS_1_2"
}

resource "google_compute_target_https_proxy" "api" {
  name             = "${local.name}-https-proxy"
  url_map          = google_compute_url_map.https.id
  ssl_certificates = [google_compute_managed_ssl_certificate.api.id]
  ssl_policy       = google_compute_ssl_policy.modern.id
}

resource "google_compute_global_address" "api" {
  name = "${local.name}-ip"
}

resource "google_compute_global_forwarding_rule" "https" {
  name                  = "${local.name}-https"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_address            = google_compute_global_address.api.address
  port_range            = "443"
  target                = google_compute_target_https_proxy.api.id
}

# Plain HTTP only redirects to HTTPS (HSTS is set by the application).
resource "google_compute_url_map" "http_redirect" {
  name = "${local.name}-http-redirect"
  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}

resource "google_compute_target_http_proxy" "redirect" {
  name    = "${local.name}-http-proxy"
  url_map = google_compute_url_map.http_redirect.id
}

resource "google_compute_global_forwarding_rule" "http" {
  name                  = "${local.name}-http"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_address            = google_compute_global_address.api.address
  port_range            = "80"
  target                = google_compute_target_http_proxy.redirect.id
}
