# 1. 建立跳板機專用的 Service Account
resource "google_service_account" "bastion_sa" {
  account_id   = "${var.resource_prefix}-sa"
  display_name = "Bastion Host Service Account"
  project      = var.project_id
}

# 2. 建立跳板機 VM (極小規格以節省成本)
resource "google_compute_instance" "bastion" {
  name         = "${var.resource_prefix}-bastion"
  machine_type = "e2-micro" # 最省錢的規格
  zone         = "${var.region}-a"
  project      = var.project_id

  # 設定網路
  network_interface {
    subnetwork = var.subnet_id
    # 不設定 access_config = {}，確保這台機器沒有外部 IP
  }

  # 作業系統映像檔
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  # 標記用於防火牆規則
  tags = ["bastion-host"]

  # 允許 IAP 透過這個 SA 進行隧道連線 (建議使用 metadata 傳遞資訊)
  metadata = {
    enable-oslogin = "TRUE"
  }

  # 將 SA 指派給 VM，並給予基礎的雲端 API 存取權限
  service_account {
    email  = google_service_account.bastion_sa.email
    scopes = ["cloud-platform"] # 設置為 cloud-platform 以便將權限管理完全交給 IAM
  }
}

# 3. 建立防火牆規則：僅允許 Google IAP 網段存取
resource "google_compute_firewall" "allow_iap_ssh" {
  name    = "${var.resource_prefix}-allow-iap-ssh"
  network = var.vpc_id # vpc 的 ID
  project = var.project_id

  # 允許 SSH 端口 (22)
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # Google IAP 的固定來源網段
  source_ranges = ["35.235.240.0/20"]
  
  # 僅套用到標記為 bastion-host 的機器
  target_tags   = ["bastion-host"]
}

# 4. 基礎日誌權限
resource "google_project_iam_member" "bastion_base_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.bastion_sa.email}"
}