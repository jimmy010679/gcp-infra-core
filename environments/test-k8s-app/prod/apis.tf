resource "google_project_service" "servicenetworking" {
  service = "servicenetworking.googleapis.com"
  project = var.test_k8s_app_project_id
  

  # 銷毀保護 (防止你關閉環境時導致其他地方服務中斷)
  disable_on_destroy = false 
}