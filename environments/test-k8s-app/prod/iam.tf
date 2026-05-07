# ====================================================================================
# 1. 授予 test-k8s-app SA 操作 GKE 的權限 (部署層身分：CI/CD 專用 Service Account)
# 用途：此 SA 由 GitHub Actions 使用，負責管理 GKE 資源的部署與維護。
# ====================================================================================
resource "google_project_iam_member" "sa_test_k8s_app_roles" {
  for_each = toset([
    "roles/container.developer",               # 允許部署 Deployment/Service
    "roles/artifactregistry.admin",            # 允許管理鏡像
    "roles/compute.networkUser",               # 允許使用 VPC 與 IP 資源 
    "roles/compute.loadBalancerAdmin",         # 允許 GKE 控制器操作外部 Load Balancer
    "roles/browser",                           # 方便在 Console 查看資源
    "roles/cloudsql.client",                   # 僅允許 Cloud SQL 連線，不允許管理 Cloud SQL 實例
    "roles/storage.objectViewer",              # 讀取 Storage
    "roles/secretmanager.viewer"               # 允許 CI/CD 查看 Secret 是否存在 (元數據)，但不允許讀取密碼內容
  ])
  
  project = var.test_k8s_app_project_id
  role    = each.key

  # 因為 SA 是在 global 建立的，這裡可以用拼接的方式引用
  member  = "serviceAccount:tf-github-test-k8s-app@${var.jimmy_infra_admin_project_id}.iam.gserviceaccount.com"
}


# ====================================================================================
# 2. 執行層身分：Pod 專用 Workload Identity SA
# 用途：此 SA 綁定於 K8s Pod，遵循最小權限原則，僅用於應用程式運行時存取 GCP 服務。
# ====================================================================================

# 1. 建立 Pod 專用的 SA 
resource "google_service_account" "pod_sa" {
  account_id   = "${var.test_k8s_app_app_name}-${var.env}-sa" # 給 Pod 用的 SA 名稱
  display_name = "Pod Secret Accessor (${var.env})"
}

# 2. 授權 Pod 允許讀取 SecretManager 中的密碼
resource "google_project_iam_member" "pod_secret_accessor" {
  project = var.test_k8s_app_project_id
  role    = "roles/secretmanager.secretAccessor" # 存取 Secret Manager

  member  = "serviceAccount:${google_service_account.pod_sa.email}"
}

# 3. 授權 Pod 能限制存取 Storage
# resource "google_storage_bucket_iam_member" "pod_storage_limited" {
#   bucket = var.bucket_name
#   role   = "roles/storage.objectCreator"
#   member = "serviceAccount:${google_service_account.pod_sa.email}"

#   condition {
#     title       = "restrict_to_images_folder"
#     expression  = "resource.name.startsWith('projects/_/buckets/${var.bucket_name}/objects/images/')"
#   }
# }