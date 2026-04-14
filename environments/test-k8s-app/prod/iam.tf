# 授予 test-k8s-app SA 操作 GKE 的權限
resource "google_project_iam_member" "sa_test_k8s_app_roles" {
  for_each = toset([
    "roles/container.developer",     # 允許部署 Deployment/Service
    "roles/artifactregistry.writer", # 允許推播鏡像，不允許刪除儲存庫
    "roles/browser"                  # 方便在 Console 查看資源
  ])
  
  project = var.test_k8s_app_project_id
  role    = each.key

  # 因為 SA 是在 global 建立的，這裡可以用拼接的方式引用
  member  = "serviceAccount:tf-github-test-k8s-app@${var.jimmy_infra_admin_project_id}.iam.gserviceaccount.com"
}