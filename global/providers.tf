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
  # 關鍵：這裡必須指向 WIF 資源所在的專案，而不是行政專案
  project = var.jimmy_infra_admin_project_id
  region  = var.jimmy_infra_admin_region
}