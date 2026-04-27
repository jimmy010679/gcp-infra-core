# 建立專屬 Data VPC
resource "google_compute_network" "data_vpc" {
  name                    = var.vpc_name
  auto_create_subnetworks = false # 大項目實務：手動管理子網以確保 IP 規劃清晰
  project                 = var.project_id

  routing_mode            = "REGIONAL" # 啟用路由限制，確保該 VPC 流量不會意外洩漏
}

# 建立私有 Subnet
resource "google_compute_subnetwork" "data_subnet" {
  name                     = var.subnet_name
  ip_cidr_range            = var.ip_range
  region                   = var.region
  network                  = google_compute_network.data_vpc.id
  project                  = var.project_id
  
  # 開啟私有 Google 存取，讓沒有公網 IP 的節點也能存取
  private_ip_google_access = true
}

# 建立預設拒絕所有流入流量的防火牆規則 (資安最佳實踐)
resource "google_compute_firewall" "deny_all_ingress" {
  name    = "${var.vpc_name}-deny-all-ingress"
  network = google_compute_network.data_vpc.name
  project = var.project_id

  deny {
    protocol = "all"
  }
  
  # 初始設定：拒絕所有來源，後續你可以根據需求新增 Allow 規則
  source_ranges = ["0.0.0.0/0"]
  priority      = 65535
}