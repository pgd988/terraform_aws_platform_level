# AWS Platform Level Services

This repository contains Terraform configurations for deploying platform-level services for the AWS account. The project is divided into separate directories, each maintaining its own independent Terraform state.

## Directory Structure

- `compute`: EC2 instance configurations (GitLab, RabbitMQ, MongoDB, Monitoring).
- `eks`: Amazon EKS cluster and node group configurations.
- `load_balancer`: Application Load Balancer with self-signed SSL/TLS termination.
- `databases`: ElastiCache for Redis and generic DynamoDB templates.
- `monitoring`: CloudWatch dashboards and alarms.
- `logging`: Centralized logging configurations.
- `iam`: Identity and Access Management roles and policies.

## Terraform Backend Setup (S3 & DynamoDB)

Each directory relies on an S3 backend with DynamoDB state locking. Because the bucket and table are managed by another repository (networking/organization repo), the `backend "s3" {}` block in each directory's `backend.tf` is intentionally left partially empty.

You **must** provide the backend configuration parameters during the `terraform init` phase. 

### How to Initialize

Navigate to the directory you wish to work on (e.g., `cd compute`), and run the initialization command, passing the variables manually:

```bash
terraform init \
  -backend-config="bucket=<YOUR_S3_BUCKET_NAME>" \
  -backend-config="key=platform-level/compute/terraform.tfstate" \
  -backend-config="region=<AWS_REGION>" \
  -backend-config="dynamodb_table=<YOUR_DYNAMODB_TABLE_NAME>"
```

*Be sure to change the `key` path for each directory to ensure states do not overlap (e.g., `platform-level/eks/terraform.tfstate` for the EKS directory).*

## Network & Foundation Dependencies

These modules will source foundational configurations (like VPC IDs, Subnet IDs, and Security Group IDs) dynamically from AWS Systems Manager (SSM) Parameter Store. When populating the configurations, variables will be exposed to specify the SSM Parameter paths.
