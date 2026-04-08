# ai_code_review 相關配置
variable "ai_code_review_project_id" {
  description = "GCP Project ID"
  type        = string
}

# 安全約束：只允許你指定的 Repo 存取
variable "authorized_repositories" {
  type    = list(string)
  default = []
}