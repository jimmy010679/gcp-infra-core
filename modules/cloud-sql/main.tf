# 1. 預留 IP 範圍 (這裡使用 var.vpc_network_id)
resource "google_compute_global_address" "private_ip_alloc" {
  name          = var.reserved_ip_range
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = var.vpc_network_id
}

# 2. 建立私有服務連線
resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = var.vpc_network_id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_alloc.name]

  depends_on = [
    google_compute_global_address.private_ip_alloc
  ]
}


# 3. Cloud SQL 實例綁定依賴
resource "google_sql_database_instance" "postgres" {
  name             = var.db_instance_name
  database_version = "POSTGRES_15"
  region           = var.region

  depends_on = [
    google_compute_global_address.private_ip_alloc,
    google_service_networking_connection.private_vpc_connection
  ]

  settings {
    tier = "db-custom-2-7680"

    # 網路安全：僅允許私有 IP
    ip_configuration {
      ipv4_enabled    = false
      private_network = var.vpc_network_id  # 連結到你的 VPC
      psc_config {
        psc_enabled               = true
        allowed_consumer_projects = [var.project_id]
      }
    }

    # 自動備份
    backup_configuration {
      enabled            = true
      point_in_time_recovery_enabled = true
      start_time         = "03:00"
    }
  }

  # true = 防止意外刪除，練習先用false
  deletion_protection = false
}