# ====================================================================================
# 
# gs://jimmy-test-k8s-env-bucket/
# ├── prod/.env
# ├── uat/.env
# └── dev/.env
# ====================================================================================
resource "google_storage_bucket" "test_k8s_bucket" {
  name          = "jimmy-test-k8s-env-bucket"
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