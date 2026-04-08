# jimmy-infra-admin 相關配置
variable "jimmy_infra_admin_project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "jimmy_infra_admin_region" {
  description = "GCP region"
  type        = string
}

# ai-code-review 相關配置
variable "ai_code_review_project_id" {
  description = "GCP Project ID"
  type        = string
}
# test-k8s-app 相關配置
variable "test_k8s_app_project_id" {
  description = "GCP Project ID"
  type        = string
}

# 安全約束：只允許你指定的 Repo 存取
variable "authorized_repositories" {
  type    = list(string)
  default = []
}