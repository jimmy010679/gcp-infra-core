# 建立應用程式專用 User
resource "google_sql_user" "app_user" {
  name     = var.db_user_name
  instance = google_sql_database_instance.postgres.name 
  project  = var.project_id
  password = random_password.db_password.result
}