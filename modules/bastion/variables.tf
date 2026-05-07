variable "project_id" {
  description = "GCP 專案 ID"
  type        = string
}

variable "region" {
  description = "資源部署的區域 (例如: asia-east1)"
  type        = string
}

variable "vpc_id" {
  description = "跳板機防火牆所屬的 VPC 網路 ID (或名稱)"
  type        = string
}

variable "subnet_id" {
  description = "跳板機 VM 所屬的子網路 ID (Self-link 或 Name)"
  type        = string
}

variable "resource_prefix" {
  description = "資源命名的前綴，通常包含應用程式名稱與環境 (例如: test-k8s-app-prod)"
  type        = string
}