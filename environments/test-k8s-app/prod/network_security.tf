# ====================================================================================
# 建立 Cloud Armor 政策
# ====================================================================================
resource "google_compute_security_policy" "waf_policy" {
  # 參數控制開啟或關閉 (練習省錢)，當開關開啟時建立 1 個，關閉時建立 0 個
  count   = var.enable_k8s_infrastructure ? 1 : 0

  name    = "${var.test_k8s_app_app_name}-frontend-${var.env}-waf-policy"
  project = var.test_k8s_app_project_id


  # Content-Type 是 application/json 的請求，請務必拆開 JSON 結構
  advanced_options_config {
    json_custom_config { content_types = ["application/json"] }
    log_level = "VERBOSE" # 詳細紀錄
  }

  # ------------------------------------------------------------------
  # 規則 1：阻擋所有外部對 /metrics 的請求 (最優先評估)
  # ------------------------------------------------------------------
  rule {
    action   = "deny(404)" # 故意回傳 404，隱藏存在
    priority = "1000"      # 優先級最高，匹配到直接攔截，不再往下走
    match {
      expr {
        expression = "request.path.matches('/metrics')"
      }
    }
    description = "Deny external access to Prometheus metrics"
  }

  # ------------------------------------------------------------------
  # 規則 2：SQL 注入防禦 (WAF 核心防線)
  # ------------------------------------------------------------------
  rule {
    action   = "deny(403)"
    priority = "1100"
    preview  = true # 如果命中了此規則，不會真的阻擋流量，穩定後改成 false
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('sqli-v33-stable')"

        # 路徑白名單，排除特定路徑寫法
        # expression = "evaluatePreconfiguredExpr('sqli-v33-stable') && !request.path.contains('/api/v1/trusted-path')"
      }
    }
    description = "SQLi Defense"
  }

  # ------------------------------------------------------------------
  # 規則 3：跨站腳本 (XSS) 防禦
  # ------------------------------------------------------------------
  rule {
    action   = "deny(403)"
    priority = "1200"
    preview  = true # 如果命中了此規則，不會真的阻擋流量，穩定後改成 false
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('xss-v33-stable')"
      }
    }
    description = "XSS Defense"
  }

  # ------------------------------------------------------------------
  # 規則 4：遠端代碼執行 (RCE) 防禦
  # ------------------------------------------------------------------
  rule {
    action   = "deny(403)"
    priority = "1300"
    preview  = true # 如果命中了此規則，不會真的阻擋流量，穩定後改成 false
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('rce-v33-stable')"
      }
    }
    description = "RCE Defense"
  }

  # ------------------------------------------------------------------
  # 預設規則：放行所有其他常規流量 (放在最底層)
  # ------------------------------------------------------------------
  rule {
    action   = "allow"
    priority = "2147483647" # 必須是最大值
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default allow rule"
  }

  lifecycle {
    create_before_destroy = true # 告訴 Terraform 先建新策略再刪舊策略，確保業務不中斷
  }
}