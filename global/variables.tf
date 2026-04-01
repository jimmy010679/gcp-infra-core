# ai_code_review 相關配置
variable "ai_code_review_project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "ai_code_review_github_repo" {
  type        = string
  description = "AI Reviewer 專案專用的 GitHub 倉庫路徑 (owner/repo)"
}