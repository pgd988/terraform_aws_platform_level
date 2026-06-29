terraform {
  backend "s3" {
    bucket         = "core-infra-terraform-state-bucket"
    key            = "load_balancer/terraform.tfstate"
    dynamodb_table = "core-infra-terraform-state-locks"
    encrypt        = true
  }
}
