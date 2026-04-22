# 建立 Artifact Registry 儲存庫
resource "google_artifact_registry_repository" "app_repo" {
  # 參數控制開啟或關閉 (練習省錢)，當開關開啟時建立 1 個，關閉時建立 0 個
  count         = var.enable_k8s_infrastructure ? 1 : 0

  location      = var.region
  repository_id = "${var.test_k8s_app_app_name}-repo"
  description   = "Docker repository for ${var.test_k8s_app_app_name}"
  format        = "DOCKER"
  project       = var.test_k8s_app_project_id

  # 建議開啟，防止誤刪
  cleanup_policies {
    id     = "keep-minimum-versions"
    action = "KEEP"
    most_recent_versions {
      keep_count = 5
    }
  }
}