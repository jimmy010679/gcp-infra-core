# 讀取在 ~/global/wif.tf 內定義的 sa
data "google_service_account" "sa_gcp_infra_core" {
  account_id = "tf-github-gcp-infra-core"
  project    = var.jimmy_infra_admin_project_id
}

# ====================================================================================
# 跨環境變數儲存庫 (GCS Bucket Configuration)
# 
# gs://jimmy-infra-admin-shared-env-bucket/
# ├── test-k8s-app/
# │   ├── prod/.env
# │   ├── uat/.env
# │   └── dev/.env
# ├── ai-code-review/
# │   ├── prod/.env
# │   └── dev/.env
# ====================================================================================
resource "google_storage_bucket" "env_bucket" {
  name          = "jimmy-infra-admin-shared-env-bucket"
  location      = var.region
  storage_class = "STANDARD"

  # 實務上開啟版本控制，避免誤刪或覆蓋環境變數
  versioning {
    enabled = true
  }

  # 刪除保護機制 (非必要練習可關閉，正式環境建議開啟)
  force_destroy               = false
  uniform_bucket_level_access = true

  # 生命週期設定 (保留舊版本)
  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      num_newer_versions = 5
      with_state         = "ARCHIVED"
    }
  }
}

# 2. 跨專案授予權限：讓 gcp-infra-core 的 SA 具備讀取此 Bucket 的權限
resource "google_storage_bucket_iam_member" "infra_sa_env_viewer" {
  bucket = google_storage_bucket.env_bucket.name
  role   = "roles/storage.objectViewer"

  member = "serviceAccount:${data.google_service_account.sa_gcp_infra_core.email}"
}