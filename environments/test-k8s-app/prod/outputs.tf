# 輸出 GKE 集群名稱
output "gke_cluster_name" {
  description = "部署成功的 GKE 集群名稱"
  # 使用 try 或條件式，避免 count=0 時噴錯
  value       = var.enable_k8s_infrastructure ? google_container_cluster.primary[0].name : "Disabled"
}

# 輸出 VPC 名稱 (從模組轉手輸出)
output "network_name" {
  description = "集群所屬的 VPC 網路"
  value       = var.enable_k8s_infrastructure ? module.network[0].vpc_name : "Disabled"
}


# 輸出儲存庫位址 (供 K8s Deployment 使用)
output "artifact_registry_repo_url" {
  description = "Artifact Registry 儲存庫完整位址"
  value       = var.enable_k8s_infrastructure ? "${var.region}-docker.pkg.dev/${var.test_k8s_app_project_id}/${google_artifact_registry_repository.app_repo[0].repository_id}" : "Disabled"
}