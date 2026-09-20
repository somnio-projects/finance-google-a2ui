# Production/staging infrastructure for the finance-a2ui backend on Google Cloud
# (ADR-F: Cloud Run + Cloud SQL). Applied per environment with
#   terraform init -backend-config="bucket=<state-bucket>" -backend-config="prefix=finance-a2ui/<env>"
#   terraform apply -var-file=environments/<env>.tfvars
# Status: committed and validated; first apply happens with the deploy epic GGU-29.

terraform {
  required_version = ">= 1.9"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    # Used for exactly one resource: `google_project_service_identity`, which
    # creates a Google-managed service agent (secrets.tf). It has no GA
    # equivalent, and the alternative — granting a role to a service account
    # that Google has not created yet — fails the apply. Same version line as
    # the GA provider so the two never drift apart.
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    # One resource: the propagation wait for Secret Manager's service agent
    # (secrets.tf). `time_sleep` is the supported way to express "this Google
    # -managed identity is not visible to IAM yet"; a provisioner would not be.
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }

  # State lives in a versioned, CMEK-optional GCS bucket created out of band
  # (docs/compliance/CLOUD_SERVICES.md §3). Partial configuration on purpose.
  backend "gcs" {}
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}
