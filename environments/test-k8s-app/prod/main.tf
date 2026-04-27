# 調用 gke-networking 模組
module "gke_networking" {
  # 參數控制開啟或關閉 (練習省錢)，當開關開啟時建立 1 個，關閉時建立 0 個
  count           = var.enable_k8s_infrastructure ? 1 : 0

  source          = "../../../modules/gke-networking"
  project_id      = var.test_k8s_app_project_id
  region          = var.region

  # 使用環境變數命名，確保 VPC 獨立
  vpc_name        = "${var.test_k8s_app_app_name}-${var.env}-app-vpc"
  subnet_name     = "${var.test_k8s_app_app_name}-${var.env}-app-subnet"

  # 每個環境建議分配不同的網段，避免未來做 VPC Peering 時衝突
  # prod: 10.10.0.0/24, uat: 10.20.0.0/24, dev: 10.30.0.0/24
  ip_range        = var.env == "prod" ? "10.10.0.0/24" : (var.env == "uat" ? "10.20.0.0/24" : "10.30.0.0/24")
  
  resource_prefix = "${var.test_k8s_app_app_name}-${var.env}"

  # Cloud NAT IP數量 (連外網IP數量)
  nat_ip_count    = 1
}

# 調用 data-vpc 模組，給 cloud-sql 使用
module "data_vpc" {
  # 參數控制開啟或關閉 (練習省錢)，當開關開啟時建立 1 個，關閉時建立 0 個
  count          = var.enable_k8s_infrastructure ? 1 : 0

  source         = "../../../modules/data-vpc"
  project_id     = var.test_k8s_app_project_id
  region         = var.region

  vpc_name       = "${var.test_k8s_app_app_name}-${var.env}-data-vpc"
  subnet_name    = "${var.test_k8s_app_app_name}-${var.env}-data-subnet"
  ip_range       = var.env == "prod" ? "10.40.0.0/24" : (var.env == "uat" ? "10.41.0.0/24" : "10.42.0.0/24") # 避開 GKE VPC 網段
}

# 調用 cloud-sql 模組 (附加 network_psc.tf)
module "cloud_sql" {
  # 參數控制開啟或關閉 (練習省錢)，當開關開啟時建立 1 個，關閉時建立 0 個
  count             = var.enable_k8s_infrastructure ? 1 : 0

  source            = "../../../modules/cloud-sql"
  project_id        = var.test_k8s_app_project_id
  region            = var.region

  vpc_network_id    = module.data_vpc[0].vpc_network_id # 串接網路模組輸出的 VPC ID
  reserved_ip_range = "prod-sql-ip-range" # IP 範圍名稱
  db_instance_name  = "${var.test_k8s_app_app_name}-${var.env}-db"
}