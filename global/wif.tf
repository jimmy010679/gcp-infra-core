# ====================================================================================
# 1. 建立 Workload Identity Pool
# ====================================================================================

# 建立 ai_reviewer_pool GCP project 的 Pool
resource "google_iam_workload_identity_pool" "new_github_pool" {
  project                   = var.ai_code_review_project_id
  workload_identity_pool_id = "github-pool-tf" 
  display_name              = "GitHub Pool Managed by TF"
  description               = "Identity pool for GitHub Actions"
}

# ====================================================================================
# 2. 建立 Workload Identity Provider (定義 GitHub 信任關係)
# ====================================================================================

# 建立 ai_reviewer_pool GCP project 的 Provider
resource "google_iam_workload_identity_pool_provider" "new_github_provider" {
  project                            = var.ai_code_review_project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.new_github_pool.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider-tf"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.actor"      = "assertion.actor"
  }
  
  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  # 安全約束：只允許你指定的 Repo 存取
  attribute_condition = "assertion.repository in ['jimmy010679/ai-code-review', 'jimmy010679/gcp-infra-core']"
}

# ====================================================================================
# 3. 建立 Service Account
# ====================================================================================

# 建立 ai-code-review Project 專屬 SA
resource "google_service_account" "sa_ai_reviewer" {
  project      = var.ai_code_review_project_id
  account_id   = "tf-github-ai-reviewer"
  display_name = "SA for AI Code Review Project"
}

# 建立 ai-code-review Repo 能變成 sa_ai_reviewer
resource "google_service_account_iam_member" "binding_ai_reviewer" {
  service_account_id = google_service_account.sa_ai_reviewer.name
  role               = "roles/iam.workloadIdentityUser"
  
  # 注意後方的 Repo 名稱路徑必須精確匹配
  member = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.new_github_pool.name}/attribute.repository/jimmy010679/ai-code-review"
}

# 建立 gcp-infra-core (Terraform 專案) 使用此 SA
resource "google_service_account_iam_member" "binding_infra_core" {
  service_account_id = google_service_account.sa_ai_reviewer.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.new_github_pool.name}/attribute.repository/jimmy010679/gcp-infra-core"
}

# 授予 SA 操作 Cloud Run、Artifact Registry 和 Service Account 的权限
resource "google_project_iam_member" "sa_roles" {
  for_each = toset([
    "roles/run.admin",
    "roles/artifactregistry.admin",
    "roles/iam.serviceAccountUser",
    "roles/browser" # 允许 Terraform 查看
  ])
  project = var.ai_code_review_project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.sa_ai_reviewer.email}"
}