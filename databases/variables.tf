variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "vpc_ssm_path" {
  type    = string
  default = "/platform/vpc/id"
}

variable "private_subnets_ssm_path" {
  type    = string
  default = "/platform/vpc/private_subnets"
}

variable "redis_sg_ssm_path" {
  type    = string
  default = "/platform/vpc/redis_sg"
}

variable "deploy_dynamodb" {
  type    = bool
  default = false
}

# RDS Configuration Variables
variable "deploy_rds" {
  description = "Switch to enable/disable RDS database deployment"
  type        = bool
  default     = false
}

variable "rds_sg_ssm_path" {
  type    = string
  default = "/platform/vpc/rds_sg"
}

variable "rds_engine" {
  type    = string
  default = "postgres"
}

variable "rds_engine_version" {
  type    = string
  default = "15"
}

variable "rds_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "rds_allocated_storage" {
  type    = number
  default = 20
}

variable "rds_db_name" {
  type    = string
  default = "platformdb"
}

variable "rds_username" {
  type    = string
  default = "dbadmin"
}

variable "rds_parameter_group_family" {
  description = "RDS parameter group family (depends on PostgreSQL major version)"
  type        = string
  default     = "postgres15"
}

variable "rds_custom_parameters" {
  description = "Custom database flags/parameters for PostgreSQL (map of flag name to value)"
  type        = map(string)
  default     = {}
}

variable "deletion_protection" {
  description = "Enable deletion protection on supported resources (RDS, DynamoDB). Set to true for production deployments."
  type        = bool
  default     = false
}
