# ====================================================================================
# 1. 基礎網路資源
# ====================================================================================
# 靜態全域 IP 分配 (維持不變，被 443 和 80 共用)
resource "google_compute_global_address" "vm_lb_ip" {
  # 參數控制開啟或關閉 (練習省錢)，當開關開啟時建立 1 個，關閉時建立 0 個
  count        = var.enable_vm_infrastructure ? 1 : 0

  name    = "${var.test_vm_app_app_name}-${var.env}-lb-ip"
  project = var.test_vm_app_project_id
}

# 建立 Google 託管的 SSL 憑證
resource "google_compute_managed_ssl_certificate" "vm_ssl_cert" {
  # 參數控制開啟或關閉 (練習省錢)，當開關開啟時建立 1 個，關閉時建立 0 個
  count        = var.enable_vm_infrastructure ? 1 : 0

  name    = "${var.test_vm_app_app_name}-${var.env}-ssl-cert"
  project = var.test_vm_app_project_id

  managed {
    domains = ["test-vm-app.kyjhome.com"] 
  }
}

# ====================================================================================
# 2. 流量入口與代理 (前端)
# ====================================================================================
resource "google_compute_target_https_proxy" "vm_https_proxy" {
  # 參數控制開啟或關閉 (練習省錢)，當開關開啟時建立 1 個，關閉時建立 0 個
  count        = var.enable_vm_infrastructure ? 1 : 0

  name             = "${var.test_vm_app_app_name}-${var.env}-https-proxy"
  project          = var.test_vm_app_project_id
  url_map          = google_compute_url_map.vm_url_map[0].id # 綁定原本處理業務的 URL Map。有用到count，必須加上[0]
  ssl_certificates = [google_compute_managed_ssl_certificate.vm_ssl_cert[0].id] # 有用到count，必須加上[0]
}

# HTTPS 轉發規則
resource "google_compute_global_forwarding_rule" "vm_https_forwarding_rule" {
  # 參數控制開啟或關閉 (練習省錢)，當開關開啟時建立 1 個，關閉時建立 0 個
  count        = var.enable_vm_infrastructure ? 1 : 0

  name                  = "${var.test_vm_app_app_name}-${var.env}-https-rule"
  project               = var.test_vm_app_project_id
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "443"
  target                = google_compute_target_https_proxy.vm_https_proxy[0].id # 有用到count，必須加上[0]
  ip_address            = google_compute_global_address.vm_lb_ip[0].id # 有用到count，必須加上[0]
}

resource "google_compute_target_http_proxy" "vm_http_proxy" {
  # 參數控制開啟或關閉 (練習省錢)，當開關開啟時建立 1 個，關閉時建立 0 個
  count        = var.enable_vm_infrastructure ? 1 : 0

  name    = "${var.test_vm_app_app_name}-${var.env}-http-proxy"
  project = var.test_vm_app_project_id
  url_map = google_compute_url_map.http_redirect[0].id # 有用到count，必須加上[0]
}

# HTTP 轉發規則
resource "google_compute_global_forwarding_rule" "vm_http_forwarding_rule" {
  # 參數控制開啟或關閉 (練習省錢)，當開關開啟時建立 1 個，關閉時建立 0 個
  count        = var.enable_vm_infrastructure ? 1 : 0

  name                  = "${var.test_vm_app_app_name}-${var.env}-http-rule"
  project               = var.test_vm_app_project_id
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "80"
  target                = google_compute_target_http_proxy.vm_http_proxy[0].id # 有用到count，必須加上[0]
  ip_address            = google_compute_global_address.vm_lb_ip[0].id # 有用到count，必須加上[0]
}

# ====================================================================================
# 3. 路由與後端處理 (後端) - 負責路由規則 (例如 /api 走哪裡，/ 走哪裡)
# ====================================================================================
resource "google_compute_url_map" "vm_url_map" {
  # 參數控制開啟或關閉 (練習省錢)，當開關開啟時建立 1 個，關閉時建立 0 個
  count        = var.enable_vm_infrastructure ? 1 : 0

  name            = "${var.test_vm_app_app_name}-${var.env}-url-map"
  project         = var.test_vm_app_project_id
  default_service = google_compute_backend_service.vm_backend[0].id # 有用到count，必須加上[0]
}

# HTTP -> HTTPS
resource "google_compute_url_map" "http_redirect" {
  # 參數控制開啟或關閉 (練習省錢)，當開關開啟時建立 1 個，關閉時建立 0 個
  count        = var.enable_vm_infrastructure ? 1 : 0

  name    = "${var.test_vm_app_app_name}-${var.env}-http-redirect"
  project = var.test_vm_app_project_id

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT" # 回傳 301 重定向
    strip_query            = false
  }
}

# ====================================================================================
# 4. 健康檢查 (Health Check) - 確保 Load Balancer 只把流量送到活著的 VM
# ====================================================================================
resource "google_compute_health_check" "vm_health_check" {
  # 參數控制開啟或關閉 (練習省錢)，當開關開啟時建立 1 個，關閉時建立 0 個
  count        = var.enable_vm_infrastructure ? 1 : 0

  name    = "${var.test_vm_app_app_name}-${var.env}-hc"
  project = var.test_vm_app_project_id

  http_health_check {
    port         = 3000      # 你的 Node.js 應用監聽的 Port
    request_path = "/healthz" # 你的應用必須提供一個健康檢查端點 (回傳 200 OK)
  }
}

# ====================================================================================
# 5. 後端服務 (Backend Service) - 負責管理 MIG 群組並套用健康檢查
# ====================================================================================
resource "google_compute_backend_service" "vm_backend" {
  # 參數控制開啟或關閉 (練習省錢)，當開關開啟時建立 1 個，關閉時建立 0 個
  count        = var.enable_vm_infrastructure ? 1 : 0

  name                  = "${var.test_vm_app_app_name}-${var.env}-backend"
  project               = var.test_vm_app_project_id
  port_name             = "http" # 必須與 MIG 裡的 named_port 匹配
  protocol              = "HTTP"
  health_checks         = [google_compute_health_check.vm_health_check[0].id] # 有用到count，必須加上[0]
  
  # 負載平衡策略
  load_balancing_scheme = "EXTERNAL_MANAGED" 

  # 掛載你的 MIG
  backend {
    group           = google_compute_region_instance_group_manager.mig[0].instance_group # 有用到count，必須加上[0]
    balancing_mode  = "UTILIZATION" # 根據 CPU 使用率分配流量
    capacity_scaler = 1.0
  }
 
  # 掛載 Cloud Armor
  # security_policy = google_compute_security_policy.waf_policy.id
}
