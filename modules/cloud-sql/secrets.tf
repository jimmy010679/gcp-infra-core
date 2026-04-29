# 建立 Secret "盒子" (只有盒子，沒有內容)
resource "google_secret_manager_secret" "db_password" {
  secret_id = "${var.db_instance_name}-password"
  replication {
    auto {}
  }
}