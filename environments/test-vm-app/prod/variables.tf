variable "env" {
  description = "目前的環境名稱 (e.g., prod, uat, dev)"
  type        = string
}

# jimmy-infra-admin 相關配置
variable "jimmy_infra_admin_project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "test_vm_app_project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "test_vm_app_app_name" {
  description = "應用程式或專案的識別名稱"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "asia-east1"
}

variable "enable_vm_infrastructure" {
  description = "是否啟用 vm 基礎設施"
  type        = bool
  default     = true
}