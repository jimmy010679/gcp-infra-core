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

  # 開啟 Binary Authorization 二進位授權強制執行 (避免非授權的image被掛載)
  binary_authorization {
    # 全局 二進位授權 政策
    evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  }

  # 練習環境建議關閉刪除保護
  deletion_protection = false

  # 依賴：確保網路先建好，在建立集群
  depends_on = [module.gke_networking]

  # ----------------------------------------------------------------------------
  # 開啟 GCP Secret Manager
  # ----------------------------------------------------------------------------
  secret_manager_config {
    enabled = true
  }

  # ----------------------------------------------------------------------------
  # 日志配置：決定哪些文本信息會被傳送到 Cloud Logging
  # ----------------------------------------------------------------------------
  logging_config {
    enable_components = [
      "SYSTEM_COMPONENTS",   # 系統組件：如節點狀態、Kubelet 運行情況
      "APISERVER",           # API 伺服器：紀錄誰對叢集做了什麼（審計日誌）
      "SCHEDULER",           # 調度器：紀錄 Pod 為何被指派到特定節點
      "CONTROLLER_MANAGER",  # 控制器管理器：紀錄副本集、服務狀態
      "WORKLOADS"            # 工作負載：你的應用程序（Next.js）輸出的 console.log
    ]
  }

  # ----------------------------------------------------------------------------
  # 監控配置：決定哪些數值指標會被傳送到 Cloud Monitoring
  # ----------------------------------------------------------------------------
  monitoring_config {
    enable_components = [
      "SYSTEM_COMPONENTS",   # 基礎指標：CPU 跑多少、內存剩多少
      "APISERVER",           # 控制平面：API 請求延遲、成功率
      "SCHEDULER",           # 調度狀態：Pod 分配是否出現延遲
      "CONTROLLER_MANAGER"   # 控制器狀態：同步資源的效率
    ]

    # Network Observability
    advanced_datapath_observability_config {
      enable_metrics = true
      enable_relay   = true
    }
    
    # Prometheus 生態 (k8s原生)
    # 定期去拉資料
    # 文件: https://docs.cloud.google.com/stackdriver/docs/managed-prometheus/setup-managed?hl=zh-tw#gke-autopilot
    managed_prometheus {
      enabled = true # 開啟託管 Prometheus 以採集 /metrics 數據
    }

    # OpenTelemetry 生態
    # 定期去推資料
    # 開啟 Google 完全代管的 OpenTelemetry Collector
    # 由於是beta階段，暫且不用 terrafrom 控制，並用 lifecycle 搭配
    # 文件: https://docs.cloud.google.com/kubernetes-engine/docs/concepts/managed-otel-gke?hl=zh-tw
    # 
    # 指令開啟
    # gcloud beta container clusters update test-k8s-app-prod-cluster \
    #   --project=test-k8s-app-492717 \
    #   --managed-otel-scope=COLLECTION_AND_INSTRUMENTATION_COMPONENTS \
    #   --location=asia-east1
    # 
    # 開啟 Google 完全代管的 OpenTelemetry Collector
    # managed_opentelemetry_config {
    #   scope = "COLLECTION_AND_INSTRUMENTATION_COMPONENTS"
    # }
  }

  lifecycle {
    # 告訴 Terraform：不要管我在外面對這個叢集的監控設定做了什麼修改
    ignore_changes = [
      monitoring_config
    ]
  }
}