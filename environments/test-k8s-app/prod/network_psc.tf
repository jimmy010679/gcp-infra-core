# ====================================================================================
# 建立 PSC Forwarding Rule (GKE pod + 跳板機 bastion，能連上 SQL)
# ====================================================================================
# 1. 建立 PSC IP
resource "google_compute_address" "sql_psc_ip" {
  # 參數控制開啟或關閉 (練習省錢)，當開關開啟時建立 1 個，關閉時建立 0 個
  count        = var.enable_k8s_infrastructure ? 1 : 0

  name         = "${var.test_k8s_app_app_name}-${var.env}-sql-psc-ip"
  region       = var.region
  subnetwork   = module.gke_networking[0].subnet_id
  address_type = "INTERNAL"
}

# 2. 建立 PSC 通道
resource "google_compute_forwarding_rule" "sql_psc_endpoint" {
  count                 = var.enable_k8s_infrastructure ? 1 : 0

  name                  = "${var.test_k8s_app_app_name}-${var.env}-sql-psc-endpoint"
  region                = var.region
  network               = module.gke_networking[0].vpc_network_id
  subnetwork            = module.gke_networking[0].subnet_id
  ip_address            = google_compute_address.sql_psc_ip[0].id
  target                = module.cloud_sql_postgres[0].psc_service_attachment_link
  load_balancing_scheme = "" # 留空代表 PSC
}

# 3. 建立 PSC IP Firewall
resource "google_compute_firewall" "allow_sql_psc_access" {
  count      = var.enable_k8s_infrastructure ? 1 : 0

  name       = "${var.test_k8s_app_app_name}-${var.env}-allow-sql-psc"
  network    = module.gke_networking[0].vpc_network_id

  allow {
    protocol = "tcp"
    ports    = ["5432"]
  }

  # 白名單授權，防止同vpc其他服務存取
  source_service_accounts = [
    google_service_account.pod_sa.email,       # 來自 pos_sa
    module.bastion[0].service_account_email    # 來自 跳板機 bastion模組 輸出 (bastion也有用到count，所以要注意是[0])
  ]
  
  # 限制目的地為 PSC 的 IP 地址
  destination_ranges = ["${google_compute_address.sql_psc_ip[0].address}/32"]
}