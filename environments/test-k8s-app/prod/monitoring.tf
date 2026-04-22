resource "google_monitoring_alert_policy" "nat_port_usage_alert" {
  # 參數控制開啟或關閉 (練習省錢)，當開關開啟時建立 1 個，關閉時建立 0 個
  count = var.enable_k8s_infrastructure ? 1 : 0

  display_name = "Cloud NAT Port Usage High"
  combiner     = "OR"
  conditions {
    display_name = "NAT Port Usage > 70% of Capacity"
    condition_threshold {
      # 監控 Cloud NAT 的指標 (使用了 count 省錢，所以是network[0])
      filter = "resource.type=\"nat_gateway\" AND metric.type=\"router.googleapis.com/nat/port_usage\" AND resource.labels.gateway_name=\"${module.network[0].nat_name}\""

      duration   = "60s" # 持續 60 秒超過閾值才告警，避免瞬間抖動
      comparison = "COMPARISON_GT" # Greater Than

      # 計算公式：max_ports_per_vm 是 32768，70% 大約是 22937
      threshold_value = 22937
    }
  }

  # 設定通知通道 (Notification Channel)
  # 在 monitoring 後台，手動新增通知 channel
  notification_channels = ["projects/${var.test_k8s_app_project_id}/notificationChannels/7394793882531172688"]
}