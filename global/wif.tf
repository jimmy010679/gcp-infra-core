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
  attribute_condition = "assertion.repository in ${jsonencode(var.authorized_repositories)}"
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

# 建立 ai-code-review 綁定 GitHub 信任關係
resource "google_service_account_iam_member" "binding_ai_reviewer" {
  service_account_id = google_service_account.sa_ai_reviewer.name
  role               = "roles/iam.workloadIdentityUser"
  
  # 注意後方的 Repo 名稱路徑必須精確匹配
  member = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.new_github_pool.name}/attribute.repository/jimmy010679/ai-code-review"
}

# 建立 gcp-infra-core 綁定 GitHub 信任關係
resource "google_service_account_iam_member" "binding_infra_core" {
  service_account_id = google_service_account.sa_ai_reviewer.name
  role               = "roles/iam.workloadIdentityUser"

  # 注意後方的 Repo 名稱路徑必須精確匹配
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.new_github_pool.name}/attribute.repository/jimmy010679/gcp-infra-core"
}

# 建立 test-k8s-app 綁定 GitHub 信任關係
resource "google_service_account_iam_member" "binding_test_k8s_app" {
  service_account_id = google_service_account.sa_ai_reviewer.name
  role               = "roles/iam.workloadIdentityUser"

  # 注意後方的 Repo 名稱路徑必須精確匹配
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.new_github_pool.name}/attribute.repository/jimmy010679/test-k8s-app"
}

# 授予 服務帳號 操作權限
resource "google_project_iam_member" "sa_roles" {
  for_each = toset([
    "roles/run.admin",
    "roles/artifactregistry.admin",
    "roles/iam.serviceAccountUser",
    "roles/browser"
  ])
  project = var.ai_code_review_project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.sa_ai_reviewer.email}"
}

# 授予 服務帳號 GKE 部署權限
resource "google_project_iam_member" "sa_k8s_roles" {
  for_each = toset([
    "roles/container.developer", # 允许部署 K8s 资源
    "roles/container.clusterViewer" # 允许查看集群狀態
  ])
  project = var.ai_code_review_project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.sa_ai_reviewer.email}"
}

# ====================================================================================
# 4. 跨專案權限：授予 SA 存取遠端 Terraform Backend (GCS Bucket)
# ====================================================================================

resource "google_project_iam_member" "remote_storage_access" {
  project = "jimmy-infra-admin" # 存放 tfstate 的行政管理專案
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.sa_ai_reviewer.email}" # 改用引用方式，避免打錯字
}