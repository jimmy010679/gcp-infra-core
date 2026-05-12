variable "region" {
  description = "GCP 區域"
  type        = string
  default     = "asia-east1"
}

variable "project_id" {
  description = "GCP 專案 ID"
  type        = string
}

variable "vpc_id" {
  description = "Cloud SQL 要連結的 VPC ID"
  type        = string
}

variable "vpc_network_id" {
  description = "Cloud SQL 要連結的 VPC 網路 ID"
  type        = string
}

variable "reserved_ip_range" {
  description = "用於 Private Service Access 的 IP 位址範圍名稱 (例如: 'prod-sql-range')"
  type        = string
}

variable "db_instance_name" {
  description = "資料庫實例名稱"
  type        = string
  default     = "prod-db-instance"
}

variable "postgres_major_version" {
  description = "PostgreSQL 大版本號 (例如: 13, 14, 15)"
  type        = string
  default     = "15"
}

variable "db_tier" {
  description = "資料庫機器規格"
  type        = string
  default     = "db-custom-2-7680"
}

variable "db_availability_type" {
  description = "Cloud SQL 的可用性類型 (ZONAL 或 REGIONAL)"
  type        = string
  default     = "ZONAL"
}

variable "db_name" {
  description = "資料庫名稱：應用程式連線使用的邏輯名稱"
  default = "test_k8s_app_main"
}

variable "db_user_name" {
  description = "資料庫應用程式帳號名稱"
  type        = string
  default     = "app_runner" # 設定預設值
}