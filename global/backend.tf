terraform {
  backend "gcs" {
    bucket = "jimmys-global-tfstate-bucket"
    prefix = "terraform/state/global"
  }
}