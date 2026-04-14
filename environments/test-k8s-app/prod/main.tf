# 調用 Networking 模組
module "network" {
  # 參數控制開啟或關閉 (練習省錢)，當開關開啟時建立 1 個，關閉時建立 0 個
  count       = var.enable_k8s_infrastructure ? 1 : 0

  source      = "../../../modules/networking"
  project_id  = var.test_k8s_app_project_id
  region      = var.region
  vpc_name    = "${var.test_k8s_app_app_name}-vpc"
  subnet_name = "${var.test_k8s_app_app_name}-subnet"
  ip_range    = "10.10.0.0/24" # 为 K8s 分配的網段
  
  static_ip_prefix = "test-k8s-app-ip" 
  static_ip_envs   = ["prod", "uat", "dev"]
}