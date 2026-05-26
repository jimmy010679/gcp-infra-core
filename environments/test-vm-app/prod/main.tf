# ====================================================================================
# 網路規劃地圖 (Network CIDR Allocations)
# 邏輯：10.[環境(Prod=10, UAT=20, Dev=30)].[專案(VM=20,21)].[0/24]
# ====================================================================================
locals {
  network_cidrs = {
    # VM 主網段 (分配 20)
    vm_app_subnets = {
      prod = "10.10.20.0/24"
      uat  = "10.20.20.0/24"
      dev  = "10.30.20.0/24"
    }
    
    # 資料庫 網段 (分配 21) ...
  }
}

# ====================================================================================
# 1. 定義 VM 藍圖 (Instance Template)
# ====================================================================================
resource "google_compute_instance_template" "vm_template" {
  # 參數控制開啟或關閉 (練習省錢)，當開關開啟時建立 1 個，關閉時建立 0 個
  count        = var.enable_vm_infrastructure ? 1 : 0

  name         = "test-vm-app-prod-template"
  machine_type = "e2-medium"
  project      = var.test_vm_app_project_id

  disk {
    source_image = "debian-cloud/debian-12"
    auto_delete  = true
    boot         = true

    # 指定 Balanced Persistent Disk
    # - pd-standard: 傳統HDD硬碟 (Linux)
    # - pd-balanced: 介於HDD~SSD硬碟 (Windows)
    # - pd-ssd:      SSD硬碟
    # - pd-extreme:  超級快硬碟
    disk_type    = "pd-balanced"
    
    # 50GB
    disk_size_gb = 50
  }

  network_interface {
    # 動態引用 network.tf 建立的資源
    network    = google_compute_network.vpc[0].id
    subnetwork = google_compute_subnetwork.subnet[0].id
  }

  service_account {
    email  = google_service_account.vm_app_sa.email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"] # 權限完全由 IAM 角色控制
  }

  # 開機時自動跑腳本
  metadata_startup_script = <<-EOT
    #!/bin/bash
    # 設置非互動模式，防止 apt-get 跳出提示卡住開機流程
    export DEBIAN_FRONTEND=noninteractive

    apt-get update
    apt-get install -y curl gnupg git

    echo "VM 開機完成，開始配置 Node.js 環境..."
    # 接下來可以寫你下載原始碼、設定環境變數並啟動服務的自動化邏輯
  EOT

  lifecycle {
    create_before_destroy = true # 確保滾動更新時，新藍圖建好才刪舊藍圖
  }
}

# ====================================================================================
# 2. 建立託管群組 (MIG)，實現自動擴展
# ====================================================================================
resource "google_compute_region_instance_group_manager" "mig" {
  # 參數控制開啟或關閉 (練習省錢)，當開關開啟時建立 1 個，關閉時建立 0 個
  count              = var.enable_vm_infrastructure ? 1 : 0

  name               = "${var.test_vm_app_app_name}-${var.env}-mig"
  project            = var.test_vm_app_project_id
  region             = var.region

  base_instance_name = "${var.test_vm_app_app_name}-${var.env}"

  # 引用上面的範本
  version {
    instance_template = google_compute_instance_template.vm_template[0].id # 有用到count，必須加上[0]
  }

  # 目標連接埠，給 Load Balancer 檢查用
  named_port {
    name = "http"
    port = 3000
  }

  # 滾動更新策略
  update_policy {
    type                  = "PROACTIVE"
    minimal_action        = "REPLACE"
    max_surge_fixed       = 1  # 拓展時可以多長出 1 台
    max_unavailable_fixed = 0  # 拓展時確保現有服務不中斷 (高可用)
  }
}

# ====================================================================================
# 3. 定義自動擴展策略 (Autoscaler)
# ====================================================================================
resource "google_compute_region_autoscaler" "autoscaler" {
  # 參數控制開啟或關閉 (練習省錢)，當開關開啟時建立 1 個，關閉時建立 0 個
  count   = var.enable_vm_infrastructure ? 1 : 0

  name    = "${var.test_vm_app_app_name}-${var.env}-autoscaler"
  project = var.test_vm_app_project_id
  region  = var.region
  target  = google_compute_region_instance_group_manager.mig[0].id # 有用到count，必須加上[0]

  autoscaling_policy {
    max_replicas    = 5  # 最多長到 5 台
    min_replicas    = 2  # 最少維持 2 台
    cooldown_period = 90 # 擴展後冷卻 90 秒

    cpu_utilization {
      target = 0.7 # CPU 超過 70% 就自動拓展
    }
  }
}