
# ====================================================================================
# 建立公證人與簽名金鑰
# ====================================================================================
# 1. 建立 KMS 金鑰環，用來組織和管理金鑰
resource "google_kms_key_ring" "attestor_key_ring" {
  name     = "${var.test_k8s_app_app_name}-${var.env}-attestor-key-ring"
  location = var.region
  project  = var.test_k8s_app_project_id
}

# 2. 建立 金鑰，用於數位簽名
resource "google_kms_crypto_key" "attestor_key" {
  name     = "${var.test_k8s_app_app_name}-${var.env}-attestor-key"
  key_ring = google_kms_key_ring.attestor_key_ring.id
  purpose  = "ASYMMETRIC_SIGN"

  version_template {
    algorithm = "RSA_SIGN_PSS_4096_SHA512"
  }
}

# 3. 建立 二進位授權 公證人 (Attestor)
resource "google_binary_authorization_attestor" "main_attestor" {
  name    = "${var.test_k8s_app_app_name}-${var.env}-attestor"
  project = var.test_k8s_app_project_id

  attestation_authority_note {
    note_reference = google_container_analysis_note.attestor_note.name
    public_keys {
      id = data.google_kms_crypto_key_version.latest.id
      pkix_public_key {
        public_key_pem      = data.google_kms_crypto_key_version.latest.public_key[0].pem
        signature_algorithm = "RSA_PSS_4096_SHA512"
      }
    }
  }
}

# 4. 建立容器分析筆記 (Container Analysis Note)
resource "google_container_analysis_note" "attestor_note" {
  name    = "${var.test_k8s_app_app_name}-${var.env}-attestation-note"
  project = var.test_k8s_app_project_id
  attestation_authority {
    hint {
      human_readable_name = "Attestor Note for ${var.env}"
    }
  }
}

# 5. 定義 全局 二進位授權 政策
resource "google_binary_authorization_policy" "policy" {
  project = var.test_k8s_app_project_id

  # 預設行為：除非有數位簽名，否則將攔截
  default_admission_rule {
    evaluation_mode  = "REQUIRE_ATTESTATION"
    enforcement_mode = "ENFORCED_BLOCK_AND_AUDIT_LOG"
    require_attestations_by = [
      google_binary_authorization_attestor.main_attestor.name
    ]
  }

  # 豁免名單：例如允許 Google 官方鏡像
  admission_whitelist_patterns {
    name_pattern = "gcr.io/google-containers/*"
  }
}

# 獲取金鑰版本資料
data "google_kms_crypto_key_version" "latest" {
  crypto_key = google_kms_crypto_key.attestor_key.id
}