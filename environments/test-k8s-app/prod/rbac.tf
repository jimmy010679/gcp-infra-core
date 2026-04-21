# 1. 建立 ServiceAccount
resource "kubernetes_service_account_v1" "ci_cd_sa" {
  metadata {
    name      = "ci-cd-sa"
    namespace = "prod"
  }
}

# 2. 建立 Role
resource "kubernetes_role_v1" "deploy_role" {
  metadata {
    name      = "deploy-role"
    namespace = "prod"
  }

  rule {
    api_groups = ["", "apps", "networking.k8s.io", "autoscaling", "networking.gke.io"]
    resources  = ["deployments", "services", "ingresses", "managedcertificates", "horizontalpodautoscalers", "pods", "frontendconfigs"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }
}

# 3. 建立 RoleBinding (將 SA 與 Role 綁定)
resource "kubernetes_role_binding_v1" "deploy_role_binding" {
  metadata {
    name      = "deploy-role-binding"
    namespace = "prod"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.deploy_role.metadata.0.name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.ci_cd_sa.metadata.0.name
    namespace = "prod"
  }
}