terraform {
  backend "gcs" {
    bucket = "jimmys-global-tfstate-bucket"
    prefix = "terraform/state/test-k8s-app/prod"
  }
}