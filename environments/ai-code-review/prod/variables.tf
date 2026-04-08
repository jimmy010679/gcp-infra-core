# jimmy-infra-admin 相關配置
variable "jimmy_infra_admin_project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "ai_code_review_project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "ai_code_review_app_name" {
  description = "應用程式或專案的識別名稱"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "asia-east1"
}
