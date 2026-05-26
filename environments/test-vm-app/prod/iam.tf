# ====================================================================================
# 1. 授予 test-vm-app SA 操作 VM 的權限 (部署層身分：CI/CD 專用 Service Account)
# 用途：此 SA 由 GitHub Actions 使用，負責管理 VM 資源的部署與維護。
# ====================================================================================
resource "google_project_iam_member" "sa_test_vm_app_roles" {
  for_each = toset([
    "roles/compute.instanceAdmin.v1",             # 允許 CI/CD 建立新的 Instance Template 並觸發 MIG 滾動更新
    "roles/compute.networkUser",                  # 允許 新建立的 VM 使用 VPC 與 IP 資源 
    "roles/browser",                              # 方便在 Console 查看資源
    "roles/storage.objectViewer",                 # 允許 CI/CD 需要從 GCS 抓取 .env 或代碼包
    "roles/iam.serviceAccountUser",               # 允許 CI/CD 幫新建立的 Instance Template 掛載 "vm_app_sa" 身分
  ])
  
  project = var.test_vm_app_project_id
  role    = each.key

  # 因為 SA 是在 global 建立的，這裡可以用拼接的方式引用
  member  = "serviceAccount:tf-github-test-vm-app@${var.jimmy_infra_admin_project_id}.iam.gserviceaccount.com"
}


# ====================================================================================
# 2. 建立 VM 專用的執行層身分
# ====================================================================================
# 1. 建立 VN 專用的 SA 
resource "google_service_account" "vm_app_sa" {
  account_id   = "${var.test_vm_app_app_name}-${var.env}-sa"
  display_name = "VM Application Runtime Identity (${var.env})"

  project      = var.test_vm_app_project_id
}

# 2. 授權 VM 允許讀取 SecretManager 中的密碼
resource "google_project_iam_member" "vm_secret_accessor" {
  project = var.test_vm_app_project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.vm_app_sa.email}"
}