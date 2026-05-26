terraform {
  backend "gcs" {
    bucket = "jimmys-global-tfstate-bucket"
    prefix = "terraform/state/test-vm-app/prod"
  }
}