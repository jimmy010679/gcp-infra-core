# 1. 先從 GCP 撈取該 Service Account 的即時資料
data "google_service_account" "ai_reviewer_sa" {
  # 這裡的 account_id 必須跟你在 global/wif.tf 定義的一模一樣
  account_id = "tf-github-ai-reviewer"
  project    = var.ai_code_review_project_id
}

# 2. Service Account 授予必要權限，並引用 Data Source 的 email 屬性
resource "google_project_iam_member" "sa_roles" {
  for_each = toset([
    "roles/run.developer",           # 僅限此專案的 Cloud Run 權限
    "roles/artifactregistry.writer", # 僅限此專案的 GAR 權限
    "roles/iam.serviceAccountUser"
  ])
  
  project = var.ai_code_review_project_id
  role    = each.key

  # 引用新 Data Source 的 email
  member  = "serviceAccount:${data.google_service_account.ai_reviewer_sa.email}"
}