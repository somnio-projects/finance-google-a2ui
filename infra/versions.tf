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
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
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
