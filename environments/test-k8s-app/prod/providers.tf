terraform {
  required_version = ">= 1.15.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version  = "~> 7.32"
    }
  }
}

provider "google" {
  project = var.test_k8s_app_project_id
  region  = var.region
}

# 設定 Kubernetes Provider 連線資訊
data "google_client_config" "default" {}

provider "kubernetes" {
  # 因為 main.tf 有 count(省錢)，才有[0]
  host                   = var.enable_k8s_infrastructure ? "https://${google_container_cluster.primary[0].endpoint}" : ""
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = var.enable_k8s_infrastructure ? base64decode(
    google_container_cluster.primary[0].master_auth[0].cluster_ca_certificate
  ) : ""
}
