output "instance_name" {
  description = "資料庫實例名稱"
  value       = google_sql_database_instance.postgres.name
}

output "psc_service_attachment_link" {
  description = "用於建立 PSC Endpoint 的 Service Attachment 連結"
  value       = google_sql_database_instance.postgres.psc_service_attachment_link
}

output "instance_connection_name" {
  description = "資料庫連線名稱 (用於 Cloud SQL Auth Proxy)"
  value       = google_sql_database_instance.postgres.connection_name
}

output "db_password_secret_id" {
  description = "Secret ID 給 K8s 或應用端使用"
  value = google_secret_manager_secret.db_password.id
}

output "db_password_result" {
  description = "資料庫隨機密碼明文"
  value       = random_password.db_password.result
  sensitive   = true # 敏感資訊
}