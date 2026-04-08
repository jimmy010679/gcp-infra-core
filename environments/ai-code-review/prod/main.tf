# Artifact Registry 儲存庫
resource "google_artifact_registry_repository" "my_repo" {
  location      = var.region
  repository_id = "ai-code-review-repo" # 對應 GAR_REPO_NAME
  format        = "DOCKER"

  # 防止 Terraform 意外刪除舊的 Image
  lifecycle {
    prevent_destroy = true
  }
}

# 建立 Cloud Run 服務 (基礎殼)
resource "google_cloud_run_v2_service" "hello_service" {
  name     = "${var.ai_code_review_app_name}-cloud-run" # 對應 CLOUD_RUN_SERVICE_NAME
  location = var.region

  # 允許任何人瀏覽（對外開放）
  ingress = "INGRESS_TRAFFIC_ALL"

  template {
    containers {
      # 初始先用 hello，等一下由 GitHub Actions 推送真正的 Image
      image = "us-docker.pkg.dev/cloudrun/container/hello"
      # image = "${var.region}-docker.pkg.dev/${var.ai_code_review_project_id}/ai-code-review-repo/ai-code-review-run:latest"
    }
  }

  # 告訴 Terraform 忽略 image 的變動
  # 後續由 GitHub Actions 更新 image 時，Terraform 就不會管它了
  lifecycle {
    ignore_changes = [
      template[0].containers[0].image, # 讓 CI/CD 負責更新映像檔 
      client,                          # 忽略 gcloud 自動注入資訊 
      client_version,                  # 忽略部署工具版本差異 
      template[0].labels,              # 忽略動態產生的標籤 (如 Commit SHA)
    ]

    # 視需求開啟，避免整組服務被意外刪除 
    # prevent_destroy = true
  }

  deletion_protection = false # 練習與頻繁測試用
}

# 允許公開存取 (roles/run.invoker)
resource "google_cloud_run_v2_service_iam_member" "public_access" {
  location = google_cloud_run_v2_service.hello_service.location
  name     = google_cloud_run_v2_service.hello_service.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}