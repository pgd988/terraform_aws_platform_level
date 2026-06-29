terraform {
  backend "s3" {
    bucket         = "core-infra-terraform-state-bucket"
    key            = "eks/terraform.tfstate"
    dynamodb_table = "core-infra-terraform-state-locks"
    encrypt        = true
  }
}
