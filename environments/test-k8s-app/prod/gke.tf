resource "google_container_cluster" "primary" {
  # 參數控制開啟或關閉 (練習省錢)，當開關開啟時建立 1 個，關閉時建立 0 個
  count    = var.enable_k8s_infrastructure ? 1 : 0

  # 使用環境變數命名，確保 叢集 獨立
  name     = "${var.test_k8s_app_app_name}-${var.env}-cluster"

  location = var.region
  project  = var.test_k8s_app_project_id

  # 啟用 Autopilot 模式
  enable_autopilot = true

  # 關鍵：引用 Networking 模組的輸出 (因為用了 count 參數，從物件變成陣列)
  network    = module.gke_networking[0].vpc_name
  subnetwork = module.gke_networking[0].subnet_name

  # 練習環境建議關閉刪除保護
  deletion_protection = false

  # 依賴：確保網路先建好，在建立集群
  depends_on = [module.gke_networking]


  # 開啟 GCP Secret Manager
  secret_manager_config {
    enabled = true
  }
}