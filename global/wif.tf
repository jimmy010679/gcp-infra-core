# 建立 Workload Identity Pool
resource "google_iam_workload_identity_pool" "new_github_pool" {
  project                   = var.project_id_ai_reviewer
  workload_identity_pool_id = "github-pool-tf" 
  display_name              = "GitHub Pool Managed by TF"
  description               = "Identity pool for GitHub Actions"
}

# 建立 Workload Identity Provider
resource "google_iam_workload_identity_pool_provider" "new_github_provider" {
  project                            = var.project_id_ai_reviewer
  workload_identity_pool_id          = google_iam_workload_identity_pool.new_github_pool.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider-tf"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.actor"      = "assertion.actor"
  }
  
  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  # 安全約束：只允許你指定的 Repo 存取
  attribute_condition = "assertion.repository == 'jimmy010679/ai-code-review'"
}

# 建立 Service Account
resource "google_service_account" "tf_github_sa" {
  project      = var.project_id_ai_reviewer
  account_id   = "tf-github-deployer"
  display_name = "Service Account Managed by Terraform"
}

# 將 Service Account 綁定到 WIF
resource "google_service_account_iam_member" "new_wif_binding" {
  service_account_id = google_service_account.tf_github_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.new_github_pool.name}/attribute.repository/jimmy010679/ai-code-review"
}