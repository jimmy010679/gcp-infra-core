# 輸出 GKE 集群名稱
output "gke_cluster_name" {
  description = "部署成功的 GKE 集群名稱"
  # 使用 try 或條件式，避免 count=0 時噴錯
  value       = var.enable_k8s_infrastructure ? google_container_cluster.primary[0].name : "Disabled"
}

# 輸出 VPC 名稱 (從模組轉手輸出)
output "network_name" {
  description = "集群所屬的 VPC 網路"
  value       = var.enable_k8s_infrastructure ? module.gke_networking[0].vpc_name : "Disabled"
}


# 輸出儲存庫位址 (供 K8s Deployment 使用)
output "artifact_registry_repo_url" {
  description = "Artifact Registry 儲存庫完整位址"
  value       = var.enable_k8s_infrastructure ? "${var.region}-docker.pkg.dev/${var.test_k8s_app_project_id}/${google_artifact_registry_repository.app_repo[0].repository_id}" : "Disabled"
}

# 輸出各環境的靜態 IP (透過模組轉手輸出)# 輸出各環境的靜態 IP (透過模組轉手輸出)
output "static_ip" {
  description = "每個環境對應的全球靜態 IP 地址，請將這些 IP 填入 A 紀錄"
  # 由於你的 module 使用了 count，所以需要用 [0] 存取
  value       = var.enable_k8s_infrastructure ? module.gke_networking[0].static_ip : null
}

output "sql_psc_internal_ip" {
  description = "Cloud SQL PSC 端點的內部 IP 地址 (用於跳板機連線目標)"
  # 使用 try 或條件式處理 count = 0 的情況
  value       = var.enable_k8s_infrastructure ? google_compute_address.sql_psc_ip[0].address : "Disabled"
}