# 調用 Networking 模組
module "network" {
  # 參數控制開啟或關閉 (練習省錢)，當開關開啟時建立 1 個，關閉時建立 0 個
  count       = var.enable_k8s_infrastructure ? 1 : 0

  source      = "../../../modules/gke-networking"
  project_id  = var.test_k8s_app_project_id
  region      = var.region

  # 使用環境變數命名，確保 VPC 獨立
  vpc_name    = "${var.test_k8s_app_app_name}-${var.env}-vpc"
  subnet_name = "${var.test_k8s_app_app_name}-${var.env}-subnet"

  # 每個環境建議分配不同的網段，避免未來做 VPC Peering 時衝突
  # prod: 10.10.0.0/24, uat: 10.20.0.0/24, dev: 10.30.0.0/24
  ip_range    = var.env == "prod" ? "10.10.0.0/24" : (var.env == "uat" ? "10.20.0.0/24" : "10.30.0.0/24")
  
  resource_prefix = "${var.test_k8s_app_app_name}-${var.env}"

  # Cloud NAT IP數量 (連外網IP數量)
  nat_ip_count    = 1
}