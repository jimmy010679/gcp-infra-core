terraform {
  required_version = ">= 1.15.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.32"
    }
  }
}

provider "google" {
  project         = var.ai_code_review_project_id
  region          = var.region
  billing_project = var.ai_code_review_project_id
}