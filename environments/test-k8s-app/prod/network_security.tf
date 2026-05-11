# 建立 Cloud Armor 政策: 阻擋所有外部對 /metrics 的請求
resource "google_compute_security_policy" "block_metrics" {
  name    = "${var.test_k8s_app_app_name}-frontend-${var.env}-block-metrics-access"
  project = var.test_k8s_app_project_id

  # 規則 1：阻擋所有對 /metrics 的請求
  rule {
    action   = "deny(404)" # 故意回傳 404，不讓別人知道你有這個端點
    priority = "1000"
    match {
      expr {
        expression = "request.path.matches('/metrics')"
      }
    }
    description = "Deny external access to Prometheus metrics"
  }

  # 預設規則：允許所有其他流量
  rule {
    action   = "allow"
    priority = "2147483647"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default allow rule"
  }

  lifecycle {
    create_before_destroy = true # 告訴 Terraform 先建新的，再刪舊的
  }
}