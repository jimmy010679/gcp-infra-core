# ====================================================================================
# 0. 啟動基礎設施 服務開關 API (專案基石 API，建議所有環境均開啟)
# ====================================================================================

locals {

  # =============================================================
  # 1. 基礎設施核心 (The Foundation) - 每個專案啟動時的最低門檻
  # =============================================================
  base_services = [
    "iam.googleapis.com",                  # 【身分定義】管理服務帳號 (SA) 與角色權限
    "iamcredentials.googleapis.com",       # 【認證核心】支援 WIF 換票，實作 GitHub Actions 無密鑰登入
    "serviceusage.googleapis.com",         # 【功能開關】讓 Terraform 具備啟動/禁用其他 GCP API 的能力
    "cloudresourcemanager.googleapis.com", # 【資源管理】基礎設施管理總入口，允許修改專案層級 IAM 綁定與元數據
    "storage.googleapis.com"               # 【儲存核心】建立及管理 GCS Bucket
  ]

  # =============================================================
  # 2. Serverless 輕量化組件 (Serverless Stack) - 適用於 Cloud Run
  # =============================================================
  serverless_services = [
    "run.googleapis.com",                  # 【容器託管】執行 Cloud Run 服務
    "aiplatform.googleapis.com",           #
    "artifactregistry.googleapis.com"      # 【映像檔儲存】存放與管理 Docker Container 映像檔
  ]

  # =============================================================
  # 3. 容器編排重裝組件 (GKE Stack) - 適用於高複雜度、分散式架構專案
  # =============================================================
  gke_services = [
    "container.googleapis.com",             # 【GKE核心】建立與管理 Kubernetes 叢集
    "compute.googleapis.com",               # 【計算資源】提供 VM 節點與網路基礎設施
    "artifactregistry.googleapis.com"       # 【映像檔儲存】用於存放 GKE 所需的容器映像檔
  ]

  # =============================================================
  # 4. Cloud SQL
  # =============================================================
  sql_services = [
    "sqladmin.googleapis.com",              # 【資料庫管理】建立與維護 Cloud SQL 實例
    "servicenetworking.googleapis.com",     # 【網路互連】建立 VPC Private Service Access 連線
    "secretmanager.googleapis.com"          # 【安全機制】託管應用程式的加密金鑰與資料庫帳密
  ]

  # =============================================================
  # 5. 觀測性與維運組件 (Observability & Ops Stack)
  # =============================================================
  management_services = [
    "monitoring.googleapis.com",      # 【監控核心】支援告警策略、指標採集與儀表板 
    "logging.googleapis.com",         # 【日誌核心】支援應用程式與系統日誌存儲 
    "backupdr.googleapis.com",        # 【備份容災】集中式安全資料保護機制 
    "telemetry.googleapis.com",       # 【遙測核心】GKE 託管 OpenTelemetry 的必要 API
    "cloudtrace.googleapis.com"       # 【追蹤核心】支援分散式鏈路追蹤 (Distributed Tracing)
  ]

  # =============================================================
  # 6. 零信任與容器安全組件 (Security & Compliance Stack)
  # =============================================================
  security_services = [
    "cloudkms.googleapis.com",            # 【加密核心】建立與管理金鑰環及非對稱金鑰以支援數位簽名
    "binaryauthorization.googleapis.com", # 【准入控制】強制執行二進位授權政策以防禦惡意鏡像部署
    "containeranalysis.googleapis.com"    # 【元數據庫】儲存與管理容器漏洞掃描報告與簽名證明紀錄
  ]
}

# 啟動行政專案 API
resource "google_project_service" "admin_base_services" {
  for_each = toset(concat(
    local.base_services,
    local.serverless_services,
    local.gke_services,
    local.sql_services
  ))
  
  project  = var.jimmy_infra_admin_project_id
  service  = each.key
  disable_on_destroy = false # 避免刪除 TF 時導致認證系統崩潰
}

# ai-code-review 啟動應用專案 API
resource "google_project_service" "ai_code_review_base_services" {
  # 合併 base 與 serverless 清單
  for_each = toset(concat(local.base_services, local.serverless_services))

  project  = var.ai_code_review_project_id
  service  = each.key
  disable_on_destroy = false
}

# test-k8s-app 啟動應用專案 API
resource "google_project_service" "test_k8s_app_base_services" {
  # 合併 base 與 gke 清單
  for_each = toset(concat(
    local.base_services,
    local.gke_services,
    local.sql_services,
    local.management_services,
    local.security_services
  ))

  project  = var.test_k8s_app_project_id
  service  = each.key
  disable_on_destroy = false
}

# ====================================================================================
# 1. 建立 Workload Identity Pool
# ====================================================================================

# 建立 ai_reviewer_pool GCP project 的 Pool
resource "google_iam_workload_identity_pool" "new_github_pool" {
  project                   = var.jimmy_infra_admin_project_id # 鎖在infra行政專案
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

# [跨專案權限] 允許各專案 Infra SA 存取 infra 行政專案的 GCS Backend (讀寫 tfstate)
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

# [身分檢視] 允許各專案 Infra SA 讀取行政專案內的 SA 屬性 (避免 TF Plan 時權限不足)
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

# [跨專案管理] 授予 Infra SA 對旗下專案的 IAM 管理權 (使其具備修改各專案權限清單的能力)
resource "google_project_iam_member" "sa_infra_core_cross_project_access" {
  for_each = toset([
    var.ai_code_review_project_id,
    var.test_k8s_app_project_id
  ])
  
  project = each.key
  role    = "roles/resourcemanager.projectIamAdmin" # 為了管理各專案的 IAM
  member  = "serviceAccount:${google_service_account.sa_gcp_infra_core.email}"
}

# [跨專案管理] 授予 Infra SA 對旗下專案的服務啟用權 (使其具備自動化開啟/管理 GCP API 的能力)
resource "google_project_iam_member" "sa_infra_core_cross_project_service_access" {
  for_each = toset([
    var.ai_code_review_project_id,
    var.test_k8s_app_project_id
  ])
  
  project = each.key
  role    = "roles/serviceusage.serviceUsageAdmin" # 核心權限：允許 TF 自動啟用目標專案所需的基礎服務 API
  member  = "serviceAccount:${google_service_account.sa_gcp_infra_core.email}"
}

# [跨專案管理] 授予 Infra SA 對 ai-code-review 應用專案的資源管理權 (使其能實際部署與操作 Cloud Run/GAR 等資源)
resource "google_project_iam_member" "infra_admin_ai_review" {
  for_each = toset([
    "roles/artifactregistry.repoAdmin",  # 管理/讀取 GAR 儲存庫
    "roles/run.admin",                   # 管理/讀取 Cloud Run 服務
    "roles/browser"                      # 基礎檢索權：允許 TF 讀取專案資源清單以進行狀態對比
  ])
  
  project = var.ai_code_review_project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.sa_gcp_infra_core.email}"
}

# [跨專案管理] 授予 Infra SA 對 test-k8s-app 的管理權限 (GKE Stack)
resource "google_project_iam_member" "infra_admin_test_k8s" {
  for_each = toset([
    "roles/artifactregistry.repoAdmin",         # 管理/讀取 GAR 儲存庫
    "roles/compute.networkAdmin",               # 解決網路 403
    "roles/container.admin",                    # 解決 GKE 403
    "roles/browser",                            # 基礎檢索權：允許 TF 讀取專案資源清單以進行狀態對比
    "roles/monitoring.editor",                  # 管理監控資源
    "roles/cloudsql.admin",                     # 建立、修改、刪除 Cloud SQL 實例
    "roles/servicenetworking.networksAdmin",    # 確保能管理私有服務連線 (PSA)
    "roles/iam.serviceAccountAdmin",            # 讓 Terraform 可以建立、讀取、修改該專案的 SA
    "roles/storage.admin",                      # 管理 GCS 檔案
    "roles/secretmanager.admin",                # 允許 TF 在專案內建立與讀取密鑰 (解決 Secret 403)
    "roles/serviceusage.serviceUsageConsumer",  # 允許 TF 消耗 API 額度 (解決 Cloud SQL API disabled 幽靈報錯)

    # # Binary Authorization 流水線簽名與驗證權限
    "roles/cloudkms.admin",                     # 允許建立與管理 KMS 金鑰環與金鑰
    "roles/binaryauthorization.admin",          # 允許建立 Attestor 與配置二進位授權政策
    "roles/containeranalysis.admin",            # 允許建立 Container Analysis Notes
  ])
  
  project = var.test_k8s_app_project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.sa_gcp_infra_core.email}"
}

# [行政專案自管理] 授予 Infra SA 對 infra行政專案 的完全控制權 (使其具備自定義 WIF 信任關係與管理身分的能力)
resource "google_project_iam_member" "sa_gcp_infra_core_roles" {
  for_each = toset([
    "roles/iam.workloadIdentityPoolAdmin",   # 管理 WIF Pool/Provider
    "roles/iam.serviceAccountAdmin",         # 管理 SA
    "roles/serviceusage.serviceUsageAdmin",  # 管理 API 啟動
    "roles/resourcemanager.projectIamAdmin", # 修改 IAM 綁定
    "roles/iam.serviceAccountTokenCreator",  # 取跨專案的 Token
    "roles/browser"                          # 確保能在 Console 或 API 讀取資源清單
  ])
  project = var.jimmy_infra_admin_project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.sa_gcp_infra_core.email}"
}
