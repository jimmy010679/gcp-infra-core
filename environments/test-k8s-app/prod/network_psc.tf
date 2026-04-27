# 建立 PSC Forwarding Rule (GKE 能連上 SQL)
resource "google_compute_address" "sql_psc_ip" {
  count        = var.enable_k8s_infrastructure ? 1 : 0
  name         = "${var.test_k8s_app_app_name}-${var.env}-sql-psc-ip"
  subnetwork   = module.gke_networking[0].subnet_id
  address_type = "INTERNAL"
  region       = var.region
}

resource "google_compute_forwarding_rule" "sql_psc_endpoint" {
  count                 = var.enable_k8s_infrastructure ? 1 : 0
  name                  = "${var.test_k8s_app_app_name}-${var.env}-sql-psc-endpoint"
  region                = var.region
  network               = module.gke_networking[0].vpc_network_id
  subnetwork            = module.gke_networking[0].subnet_id
  ip_address            = google_compute_address.sql_psc_ip[0].id
  target                = module.cloud_sql[0].psc_service_attachment_link
  load_balancing_scheme = "" # 留空代表 PSC
}