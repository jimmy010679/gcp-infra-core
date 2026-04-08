# ====================================================================================
# 0. 啟動基礎三劍客 API (infra行政專案皆建議開啟)
# ====================================================================================

locals {
  base_services = [
    "iam.googleapis.com",                 # 管理 SA 與權限
    "iamcredentials.googleapis.com",      # 關鍵：支援 WIF 換票認證
    "serviceusage.googleapis.com",        # 讓 TF 能檢查/管理其他 API 狀態
    "cloudresourcemanager.googleapis.com" # 基礎設施管理總入口，允許 TF 修改專案層級的 IAM 與 API 狀態
  ]
}

# 啟動行政專案 API
resource "google_project_service" "admin_base_services" {
  for_each = toset(local.base_services)
  project  = var.jimmy_infra_admin_project_id
  service  = each.key
  disable_on_destroy = false # 避免刪除 TF 時導致認證系統崩潰
}

# ai-code-review 啟動應用專案 API
resource "google_project_service" "app_base_services" {
  for_each = toset(local.base_services)
  project  = var.ai_code_review_project_id
  service  = each.key
  disable_on_destroy = false
}

# ====================================================================================
# 1. 建立 Workload Identity Pool
# ====================================================================================

# 建立 ai_reviewer_pool GCP project 的 Pool
resource "google_iam_workload_identity_pool" "new_github_pool" {
  project                   = var.jimmy_infra_admin_project_id # 鎖在行政專案
  workload_identity_pool_id = "github-pool-tf" 
  display_name              = "GitHub Pool Managed by TF"
  description               = "Identity pool for GitHub Actions"

  # 確保infra行政專案的基礎 API 開啟後再建立 Pool
  depends_on = [google_project_service.admin_base_services]
}

# ====================================================================================
# 2. 建立 Workload Identity Provider (定義 GitHub 信任關係)
# ====================================================================================

# 建立 ai_reviewer_pool GCP project 的 Provider
resource "google_iam_workload_identity_pool_provider" "new_github_provider" {
  project                            = var.jimmy_infra_admin_project_id
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

  # 確保 Pool 與基礎 API 都就緒
  depends_on = [
    google_iam_workload_identity_pool.new_github_pool,
    google_project_service.admin_base_services
  ]
}

# ====================================================================================
# 3. 建立 Service Account
# ====================================================================================

# 建立 gcp-infra-core Project 專屬 SA
resource "google_service_account" "sa_gcp_infra_core" {
  project      = var.jimmy_infra_admin_project_id
  account_id   = "tf-github-gcp-infra-core"
  display_name = "SA for GCP Infra Core Project"
  depends_on = [google_project_service.admin_base_services]
}

# 建立 ai-code-review Project 專屬 SA
resource "google_service_account" "sa_ai_code_review" {
  project      = var.jimmy_infra_admin_project_id
  account_id   = "tf-github-ai-code-review"
  display_name = "SA for AI Code Review Project"
  depends_on = [google_project_service.admin_base_services]
}

# 建立 test-k8s-app Project 專屬 SA
resource "google_service_account" "sa_test_k8s_app" {
  project      = var.jimmy_infra_admin_project_id
  account_id   = "tf-github-test-k8s-app"
  display_name = "SA for Test k8s APP Project"
  depends_on = [google_project_service.admin_base_services]
}

# ====================================================================================
# 4. 信任關係
# ====================================================================================

# 建立 gcp-infra-core 綁定 GitHub 信任關係
resource "google_service_account_iam_member" "binding_infra_core" {
  service_account_id = google_service_account.sa_gcp_infra_core.name
  role               = "roles/iam.workloadIdentityUser"

  # 注意後方的 Repo 名稱路徑必須精確匹配
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.new_github_pool.name}/attribute.repository/jimmy010679/gcp-infra-core"
}

# 建立 ai-code-review 綁定 GitHub 信任關係
resource "google_service_account_iam_member" "binding_ai_reviewer" {
  service_account_id = google_service_account.sa_ai_code_review.name
  role               = "roles/iam.workloadIdentityUser"
  
  # 注意後方的 Repo 名稱路徑必須精確匹配
  member = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.new_github_pool.name}/attribute.repository/jimmy010679/ai-code-review"
}

# 建立 test-k8s-app 綁定 GitHub 信任關係
resource "google_service_account_iam_member" "binding_test_k8s_app" {
  service_account_id = google_service_account.sa_test_k8s_app.name
  role               = "roles/iam.workloadIdentityUser"

  # 注意後方的 Repo 名稱路徑必須精確匹配
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.new_github_pool.name}/attribute.repository/jimmy010679/test-k8s-app"
}

# ====================================================================================
# 5. 授予 服務帳號 操作權限
# ====================================================================================

# [通用權限] 建立一個清單，讓 SA 都能存取 tfstate
resource "google_project_iam_member" "remote_storage_access" {
  for_each = toset([
    google_service_account.sa_gcp_infra_core.email,
    google_service_account.sa_ai_code_review.email,
    google_service_account.sa_test_k8s_app.email
  ])
  project = var.jimmy_infra_admin_project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${each.key}"
}

# [通用權限] 建立一個清單，讓 SA 都能讀取行政專案內的 SA 資訊
resource "google_project_iam_member" "sa_self_viewer" {
  for_each = toset([
    google_service_account.sa_gcp_infra_core.email,
    google_service_account.sa_ai_code_review.email,
    google_service_account.sa_test_k8s_app.email
  ])
  project = var.jimmy_infra_admin_project_id
  role    = "roles/iam.serviceAccountViewer"
  member  = "serviceAccount:${each.key}"
}

# [跨專案管理] 讓 gcp-infra-core 有權管理旗下專案
resource "google_project_iam_member" "sa_infra_core_cross_project_access" {
  for_each = toset([
    var.ai_code_review_project_id,
    var.test_k8s_app_project_id
  ])
  
  project = each.key
  role    = "roles/resourcemanager.projectIamAdmin" # 為了管理各專案的 IAM
  member  = "serviceAccount:${google_service_account.sa_gcp_infra_core.email}"
}

# [跨專案管理] 讓 gcp-infra-core 有權管理旗下專案
resource "google_project_iam_member" "sa_infra_core_cross_project_service_access" {
  for_each = toset([
    var.ai_code_review_project_id,
    var.test_k8s_app_project_id
  ])
  
  project = each.key
  role    = "roles/serviceusage.serviceUsageAdmin" # 為了管理各專案的 API (三劍客)
  member  = "serviceAccount:${google_service_account.sa_gcp_infra_core.email}"
}

# [專案權限] 授予 gcp-infra-core 服務帳號 管理行政專案(WIF/IAM/API) 的權限
resource "google_project_iam_member" "sa_gcp_infra_core_roles" {
  for_each = toset([
    "roles/iam.workloadIdentityPoolAdmin",  # 管理 WIF Pool/Provider
    "roles/iam.serviceAccountAdmin",        # 管理 SA
    "roles/serviceusage.serviceUsageAdmin", # 管理 API 啟動
    "roles/resourcemanager.projectIamAdmin" # 修改 IAM 綁定
  ])
  project = var.jimmy_infra_admin_project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.sa_gcp_infra_core.email}"
}

# [專案權限] 授予 test-k8s-app 服務帳號 GKE 部署權限
resource "google_project_iam_member" "sa_test_k8s_app_roles" {
  for_each = toset([
    "roles/container.developer", # 允许部署 K8s 资源
    "roles/container.clusterViewer" # 允许查看集群狀態
  ])
  project = var.test_k8s_app_project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.sa_test_k8s_app.email}"
}

