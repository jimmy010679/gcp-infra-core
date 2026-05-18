# Cloud NAT Port 使用率監控
resource "google_monitoring_alert_policy" "nat_port_usage_alert" {
  # 參數控制開啟或關閉 (練習省錢)，當開關開啟時建立 1 個，關閉時建立 0 個
  count = var.enable_k8s_infrastructure ? 1 : 0

  display_name = "${var.test_k8s_app_app_name} (${var.env}) - Cloud NAT Port Usage High"
  combiner     = "OR"
  conditions {
    display_name = "NAT Port Usage > 80% of Capacity"
    condition_threshold {
      # 監控指標：整個 NAT Gateway 已分配的端口總數 (使用了 count 省錢，所以是network[0])
      filter = "resource.type=\"nat_gateway\" AND metric.type=\"router.googleapis.com/nat/allocated_ports\" AND resource.labels.gateway_name=\"${module.gke_networking[0].nat_name}\""

      duration   = "300s"          # 持續5min超過閾值才告警，避免瞬間抖動
      comparison = "COMPARISON_GT" # Greater Than

      # 動態計算：(單個 IP 總量 64512 * 模塊輸出的 IP 數量) * 0.8 閾值
      threshold_value = (64512 * module.gke_networking[0].nat_ip_count) * 0.8
    }
  }

  # 設定通知通道 (Notification Channel)
  # 在 monitoring 後台，手動新增通知 channel
  notification_channels = ["projects/${var.test_k8s_app_project_id}/notificationChannels/7394793882531172688"]
}


# nextjs 監控 (Prometheus 生態)
# resource "kubernetes_manifest" "nextjs_pod_monitoring" {
#   manifest = {
#     apiVersion = "monitoring.googleapis.com/v1"
#     kind       = "PodMonitoring"
#     metadata = {
#       name      = "${var.test_k8s_app_app_name}-frontend-${var.env}-metrics"
#       namespace = var.env
#     }
#     spec = {
#       selector = {
#         matchLabels = {
#           app = "${var.test_k8s_app_app_name}-frontend-${var.env}" # 與 Deployment.yaml Label 一致 (ex: test-k8s-app-frontend-prod)
#         }
#       }
#       endpoints = [
#         {
#           port     = "http"      # 應用程式容器開放的端口名稱 Deployment.yaml ContainerPort Name
#           path     = "/metrics"  # 指標路徑
#           interval = "30s"       # 抓取頻率
#         }
#       ]
#     }
#   }
# }