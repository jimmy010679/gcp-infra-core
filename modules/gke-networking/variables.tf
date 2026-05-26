variable "project_id" {
  description = "GCP 專案 ID"
  type        = string
}

variable "region" {
  description = "部署區域"
  type        = string
}

variable "vpc_name" {
  description = "VPC 網路名稱"
  type        = string
}

variable "subnet_name" {
  description = "子網名稱"
  type        = string
}

variable "ip_range" {
  description = "子網 IP 範圍 (例如 10.0.0.0/24)"
  type        = string
  default     = "10.0.0.0/24"
}

variable "resource_prefix" {
  description = "資源命名的前綴，用於區分不同的專案或應用"
  type        = string
}

variable "nat_ip_count" {
  description = "Cloud NAT 連外網手動IP數量"
  type        = number
  default     = 1
}

variable "pod_ip_range" {
  description = "給 GKE Pod 使用的次要網段 (例如 /16 或 /20)"
  type        = string
}

variable "service_ip_range" {
  description = "給 GKE Service 使用的次要網段 (例如 /20 或 /22)"
  type        = string
}