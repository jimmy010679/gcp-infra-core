# 1. 先從 GCP 撈取該 Service Account 的即時資料
data "google_service_account" "ai_reviewer_sa" {
  # 這裡的 account_id 必須跟你在 global/wif.tf 定義的一模一樣
  account_id = "tf-github-ai-code-review"
  project    = var.jimmy_infra_admin_project_id
}

# 2. Service Account 授予必要權限，並引用 Data Source 的 email 屬性
resource "google_project_iam_member" "sa_ai_code_review_roles" {
  for_each = toset([
    "roles/run.admin",              # 確保 TF Plan 能讀取 Cloud Run 完整現狀
    "roles/artifactregistry.admin", # 管理 GAR 儲存庫
    "roles/iam.serviceAccountUser", # 部署時必要的扮演權限
    "roles/browser"                 # 允許在控制台瀏覽資源 (選配)
  ])
  
  project = var.ai_code_review_project_id
  role    = each.key

  # 引用新 Data Source 的 email
  member  = "serviceAccount:${data.google_service_account.ai_reviewer_sa.email}"
}