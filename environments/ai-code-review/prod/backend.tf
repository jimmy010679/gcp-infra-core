terraform {
  backend "gcs" {
    bucket = "jimmys-global-tfstate-bucket"
    prefix = "terraform/state/ai-code-review/prod"
  }
}