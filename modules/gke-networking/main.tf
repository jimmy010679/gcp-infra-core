# 建立專屬 VPC 網路
resource "google_compute_network" "vpc" {
  name                    = var.vpc_name
  auto_create_subnetworks = false # 大項目實務：手動管理子網以確保 IP 規劃清晰
  project                 = var.project_id
}

# 建立 GKE 專用子網
resource "google_compute_subnetwork" "subnet" {
  name                     = var.subnet_name
  ip_cidr_range            = var.ip_range
  region                   = var.region
  network                  = google_compute_network.vpc.id
  project                  = var.project_id

  # 開啟私有 Google 存取，讓沒有公網 IP 的節點也能存取 Artifact Registry
  private_ip_google_access = true 
}

# 建立 Cloud Router (為 Cloud NAT 提供邏輯支撐)
resource "google_compute_router" "router" {
  name    = "${var.vpc_name}-router"
  region  = var.region
  network = google_compute_network.vpc.id
  project = var.project_id
}

# 建立 靜態 IP (有網路發出的公網 IP)
resource "google_compute_address" "nat_ips" {
  count  = var.nat_ip_count
  name   = "${var.vpc_name}-nat-ip-${count.index}"
  region = var.region
}

# 建立 Cloud NAT (讓 K8s 節點可以安全地存取外部網路抓取套件)
resource "google_compute_router_nat" "nat" {
  name                               = "${var.vpc_name}-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  project                            = var.project_id

  # 私有網路發出的公網 IP
  nat_ip_allocate_option             = "MANUAL_ONLY" # "AUTO_ONLY" or "MANUAL_ONLY" (需搭配nat_ips)
  
  # 綁定上面建立的 IP
  nat_ips                            = google_compute_address.nat_ips[*].self_link

  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  enable_dynamic_port_allocation     = true  # 啟用動態埠分配
  min_ports_per_vm                   = 64
  max_ports_per_vm                   = 2048
}

# 建立 全球靜態IP
resource "google_compute_global_address" "ingress_ip" {
  project      = var.project_id
  name         = "${var.resource_prefix}-static-ip"
  address_type = "EXTERNAL"
  ip_version   = "IPV4"
}