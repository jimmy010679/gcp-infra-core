# ====================================================================================
# 網路規劃地圖 (Network CIDR Allocations)
# 邏輯：10.[環境(Prod=10, UAT=20, Dev=30)].[專案與用途].[0/24]
# ====================================================================================
locals {
  network_cidrs = {
    # k8s 網段 (分配 10)
    k8s_app_subnets = {
      prod = "10.10.10.0/24"
      uat  = "10.20.10.0/24"
      dev  = "10.30.10.0/24"
    }
    
    # 資料庫 網段 (分配 11)
    data_subnets = {
      prod = "10.10.11.0/24"
      uat  = "10.20.11.0/24"
      dev  = "10.30.11.0/24"
    }

    # K8s 次要網段 - Pods (分配 100)
    k8s_pod_ranges = {
      prod = "10.10.100.0/16"
      uat  = "10.20.100.0/16"
      dev  = "10.30.100.0/16"
    }

    # K8s 次要網段 - Services (分配 101)
    k8s_service_ranges = {
      prod = "10.10.101.0/20"
      uat  = "10.20.101.0/20"
      dev  = "10.30.101.0/20"
    }
  }
}


# ====================================================================================
# GKE
# ====================================================================================
# 調用 gke-networking 模組
module "gke_networking" {
  # 參數控制開啟或關閉 (練習省錢)，當開關開啟時建立 1 個，關閉時建立 0 個
  count            = var.enable_k8s_infrastructure ? 1 : 0

  source           = "../../../modules/gke-networking"
  project_id       = var.test_k8s_app_project_id
  region           = var.region

  # 使用環境變數命名，確保 VPC 獨立
  vpc_name         = "${var.test_k8s_app_app_name}-${var.env}-app-vpc"
  subnet_name      = "${var.test_k8s_app_app_name}-${var.env}-app-subnet"

  # 每個環境建議分配不同的網段，避免未來做 VPC Peering 時衝突
  ip_range         = local.network_cidrs.k8s_app_subnets[var.env]

  # Pod 和 Service 的次要網段
  pod_ip_range     = local.network_cidrs.k8s_pod_ranges[var.env]
  service_ip_range = local.network_cidrs.k8s_service_ranges[var.env]
  
  # 資源命名的前綴，用於區分不同的專案或應用
  resource_prefix  = "${var.test_k8s_app_app_name}-${var.env}"

  # Cloud NAT IP數量 (連外網IP數量)
  nat_ip_count     = 1
}

# ====================================================================================
# 資料庫
# ====================================================================================
# 調用 data-vpc 模組，給 cloud-sql-postgres 使用
module "data_vpc" {
  # 參數控制開啟或關閉 (練習省錢)，當開關開啟時建立 1 個，關閉時建立 0 個
  count          = var.enable_k8s_infrastructure ? 1 : 0

  source         = "../../../modules/data-vpc"
  project_id     = var.test_k8s_app_project_id
  region         = var.region

  vpc_name       = "${var.test_k8s_app_app_name}-${var.env}-data-vpc"
  subnet_name    = "${var.test_k8s_app_app_name}-${var.env}-data-subnet"
  ip_range       = local.network_cidrs.data_subnets[var.env] # 避開 GKE VPC 網段
}

# 調用 cloud-sql-postgres 模組 (附加 network_psc.tf)
module "cloud_sql_postgres" {
  # 參數控制開啟或關閉 (練習省錢)，當開關開啟時建立 1 個，關閉時建立 0 個
  count                   = var.enable_k8s_infrastructure ? 1 : 0

  source                  = "../../../modules/cloud-sql-postgres"
  project_id              = var.test_k8s_app_project_id
  region                  = var.region

  vpc_id                  = module.data_vpc[0].vpc_id
  vpc_network_id          = module.data_vpc[0].vpc_network_id # 串接網路模組輸出的 VPC ID
  reserved_ip_range       = "${var.test_k8s_app_app_name}-${var.env}-sql-ip-range" # IP 範圍名稱
  db_instance_name        = "${var.test_k8s_app_app_name}-${var.env}-db"
  postgres_major_version  = "15"
  db_tier                 = "db-g1-small"
  db_availability_type    = "ZONAL"
  db_name                 = "${replace(var.test_k8s_app_app_name, "-", "_")}_main" # ex: test_k8s_app_main
  db_user_name            = "app_runner"

  depends_on = [
    google_project_service.servicenetworking, # 等待啟用 API (servicenetworking.googleapis.com)
    module.data_vpc
  ]
}

# ====================================================================================
# 跳板機
# ====================================================================================
# 調用 bastion 模組，使用跳板機+IAP，讓本機連得到DB，需登入gcloud
# 
# 使用方式:
# gcloud compute ssh [app-vpc-跳板機名稱] \
#     --tunnel-through-iap \
#     --project [專案_ID] \
#     --zone [區域] \
#     -- -L 5432:[PSC_FORWARDING_RULE_IP或你的_Cloud_SQL_私有IP]:5432 -N

module "bastion" {
  # 參數控制開啟或關閉 (練習省錢)，當開關開啟時建立 1 個，關閉時建立 0 個
  count           = var.enable_k8s_infrastructure ? 1 : 0

  source          = "../../../modules/bastion"
  project_id      = var.test_k8s_app_project_id
  region          = var.region
  
  vpc_id          = module.gke_networking[0].vpc_network_id 
  subnet_id       = module.gke_networking[0].subnet_id
  
  resource_prefix = "${var.test_k8s_app_app_name}-${var.env}"

  depends_on = [
    module.gke_networking,
    module.data_vpc,
    module.cloud_sql_postgres
  ]
}


# ====================================================================================
# Kubernetes  配置
# ====================================================================================
# 建立 Namespace
resource "kubernetes_namespace_v1" "prod" {
  # 參數控制開啟或關閉 (練習省錢)，當開關開啟時建立 1 個，關閉時建立 0 個
  count = var.enable_k8s_infrastructure ? 1 : 0

  metadata {
    name = var.env 

    # 啟用 K8s 官方最高級別的 Restricted 安全限制
    labels = {
      "pod-security.kubernetes.io/enforce"         = "restricted"

      # 從 GKE 集群资源中提取前兩位的版本號碼（例如 v1.35）
      "pod-security.kubernetes.io/enforce-version" = "v${regex("^[0-9]+\\.[0-9]+", google_container_cluster.primary[0].master_version)}"
    }
  }
}

# 自動生成 Kubernetes ConfigMap
# 搭配 deployment.yaml configMapRef
resource "kubernetes_config_map_v1" "app_config" {
  # 參數控制開啟或關閉 (練習省錢)，當開關開啟時建立 1 個，關閉時建立 0 個
  count = var.enable_k8s_infrastructure ? 1 : 0

  metadata {
    name      = "${var.test_k8s_app_app_name}-frontend-${var.env}-config"
    namespace = var.env
  }

  data = {
    # 引用自 network_psc.tf 中的 PSC 地址資源
    DB_HOST          = google_compute_address.sql_psc_ip[0].address
    
    # 引用自 cloud_sql_postgres 模塊的變量或輸出
    DB_USER          = "app_runner"
    DB_NAME          = "${replace(var.test_k8s_app_app_name, "-", "_")}_main" # ex: test_k8s_app_main
    DB_PORT          = "5432"
    DB_PASSWORD_PATH = "/var/secrets/db-password.txt"

    # OpenTelemetry 託管 Collector 端點
    # 會自動附加 /v1/traces
    OTEL_EXPORTER_OTLP_ENDPOINT = "http://opentelemetry-collector.gke-managed-otel.svc.cluster.local:4318"
    TRACE_SAMPLE_RATE           = "0.05" # 採樣率 5%
  }

  depends_on = [
    module.gke_networking,
    module.cloud_sql_postgres,
    google_compute_address.sql_psc_ip
  ]
}