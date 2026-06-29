terraform {
  backend "s3" {
    bucket         = "core-infra-terraform-state-bucket"
    key            = "compute/terraform.tfstate"
    dynamodb_table = "core-infra-terraform-state-locks"
    encrypt        = true
  }
}
