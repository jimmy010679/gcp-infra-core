# 1. 建立 Secret "盒子" (只有盒子，沒有內容)
resource "google_secret_manager_secret" "db_password" {
  secret_id = "${var.db_instance_name}-password"
  replication {
    auto {}
  }
}

# 2. 生成隨機密碼
resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# 3. 將內容放入盒子（版本化）
resource "google_secret_manager_secret_version" "db_password_version" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = random_password.db_password.result
}