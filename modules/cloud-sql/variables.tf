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

variable "db_tier" {
  description = "資料庫機器規格"
  type        = string
  default     = "db-custom-2-7680"
}
