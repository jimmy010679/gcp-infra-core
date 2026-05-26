# ====================================================================================
# 1. 建立自定義 VPC
# ====================================================================================
resource "google_compute_network" "vpc" {
  # 參數控制開啟或關閉 (練習省錢)，當開關開啟時建立 1 個，關閉時建立 0 個
  count                   = var.enable_vm_infrastructure ? 1 : 0
  
  name                    = "${var.test_vm_app_app_name}-${var.env}-app-vpc"
  auto_create_subnetworks = false # 手動管理子網 IP 段
  project                 = var.test_vm_app_project_id
}

# ====================================================================================
# 2. 建立 VM 專用子網 (Subnet)
# ====================================================================================
resource "google_compute_subnetwork" "subnet" {
  # 參數控制開啟或關閉 (練習省錢)，當開關開啟時建立 1 個，關閉時建立 0 個
  count                    = var.enable_vm_infrastructure ? 1 : 0
  
  name                     = "${var.test_vm_app_app_name}-${var.env}-app-subnet"
  ip_cidr_range            = local.network_cidrs.vm_app_subnets[var.env] # VM 使用的內網 IP 範圍
  region                   = var.region
  
  # 動態引用上面建立的 VPC
  network                  = google_compute_network.vpc[0].id # 有用到count，必須加上[0]
  project                  = var.test_vm_app_project_id

  # 讓沒有外部 IP 的 VM 也能透過內部網路存取 Google API (如 Secret Manager, GCS)
  private_ip_google_access = true 
}

# ====================================================================================
# 3. 建立 Cloud Router
# ====================================================================================
resource "google_compute_router" "router" {
  # 參數控制開啟或關閉 (練習省錢)，當開關開啟時建立 1 個，關閉時建立 0 個
  count   = var.enable_vm_infrastructure ? 1 : 0
  
  name    = "${var.test_vm_app_app_name}-${var.env}-router"
  region  = var.region
  network = google_compute_network.vpc[0].id
  project = var.test_vm_app_project_id
}

# ====================================================================================
# 4. 建立 NAT 專用的靜態外部 IP (Static External IP)
# ====================================================================================
resource "google_compute_address" "nat_ips" {
  # 參數控制開啟或關閉 (練習省錢)，當開關開啟時建立 1 個，關閉時建立 0 個
  count   = var.enable_vm_infrastructure ? 1 : 0
  
  name    = "${var.test_vm_app_app_name}-${var.env}-nat-ip"
  project = var.test_vm_app_project_id
  region  = var.region
}

# ====================================================================================
# 5. 建立 Cloud NAT
# ====================================================================================
resource "google_compute_router_nat" "nat" {
  # 參數控制開啟或關閉 (練習省錢)，當開關開啟時建立 1 個，關閉時建立 0 個
  count                              = var.enable_vm_infrastructure ? 1 : 0
  
  name                               = "${var.test_vm_app_app_name}-${var.env}-nat"
  router                             = google_compute_router.router[0].name
  region                             = var.region
  project                            = var.test_vm_app_project_id
  
  # 私有網路發出的公網 IP
  nat_ip_allocate_option             = "MANUAL_ONLY" # "AUTO_ONLY" or "MANUAL_ONLY" (需搭配nat_ips)

  # 綁定上面建立的 IP
  nat_ips                            = google_compute_address.nat_ips[*].self_link
  
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  enable_dynamic_port_allocation     = true # 啟用動態埠分配
  min_ports_per_vm                   = 64
  max_ports_per_vm                   = 2048

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# ====================================================================================
# 6. 建立防火牆規則：允許 Load Balancer 存取 TCP 3000 prot
# ====================================================================================
resource "google_compute_firewall" "allow_health_check_and_lb" {
  # 參數控制開啟或關閉 (練習省錢)，當開關開啟時建立 1 個，關閉時建立 0 個
  count   = var.enable_vm_infrastructure ? 1 : 0

  name    = "${var.test_vm_app_app_name}-${var.env}-allow-hc-lb"
  network = google_compute_network.vpc[0].name
  project = var.test_vm_app_project_id

  # 允許來自 LB 和 Health Check 的流量
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]

  allow {
    protocol = "tcp"
    ports    = ["3000"]
  }

  target_service_accounts = [google_service_account.vm_app_sa.email]
}

# ====================================================================================
# 7. 建立防火牆規則：允許 IAP 存取 SSH
# ====================================================================================
resource "google_compute_firewall" "allow_iap_ssh" {
  # 參數控制開啟或關閉 (練習省錢)，當開關開啟時建立 1 個，關閉時建立 0 個
  count   = var.enable_vm_infrastructure ? 1 : 0

  name    = "${var.test_vm_app_app_name}-${var.env}-allow-iap-ssh"
  network = google_compute_network.vpc[0].name
  project = var.test_vm_app_project_id

  # IAP 的固定網段 (GCP SSH, gcloud ssh)
  source_ranges = ["35.235.240.0/20"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  target_service_accounts = [google_service_account.vm_app_sa.email]
}