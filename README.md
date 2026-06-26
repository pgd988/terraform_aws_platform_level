# AWS Platform Level Services

This repository contains Terraform configurations for deploying platform-level services for the AWS account. The project is divided into separate directories, each maintaining its own independent Terraform state.

## Directory Structure

- `compute`: EC2 instance configurations (GitLab, RabbitMQ, MongoDB, Monitoring).
- `eks`: Amazon EKS cluster, node groups, add-ons (Pod Identity Agent), and foundational tooling:
  - **Argo Suite**: ArgoCD, Argo Rollouts, and Argo Events via Helm.
  - **AWS Load Balancer Controller**: Configured with strict EKS Pod Identity Least Privilege Principle (PoLP).
  - `apps/`: Default Kubernetes workloads deployed via Helm (e.g., default NGINX sink returning 403).
  - `policies/`: Self-hosted JSON IAM policies for EKS add-ons.
- `load_balancer`: Application Load Balancer with self-signed SSL/TLS termination and direct pod IP target group routing.
- `databases`: ElastiCache for Redis and generic DynamoDB templates.
- `monitoring`: CloudWatch dashboards and alarms.
- `logging`: Centralized logging configurations.
- `iam`: Identity and Access Management roles and policies.

## Architectural Highlights

### 1. EKS Pod Identity (Least Privilege Principle)
Authentication for cluster controllers (such as the AWS Load Balancer Controller) uses **Amazon EKS Pod Identity** instead of traditional IRSA. The trust policies are strictly scoped down using explicit conditions (`aws:SourceAccount`, `aws:SourceArn`, and agent session tags for namespace and service account) to guarantee PoLP.

### 2. Direct Pod-to-ALB Routing (GCP NEG Style)
The Application Load Balancer routes traffic directly to pods' IPs inside the EKS cluster bypassing `NodePort` kube-proxy hops:
- The `load_balancer` module creates an `aws_lb_target_group` with `target_type = "ip"` and exports its ARN to SSM Parameter Store (`/platform/alb/default_tg_arn`).
- The `eks/apps` module deploys an NGINX default backend pod and injects an AWS Load Balancer Controller `TargetGroupBinding` Custom Resource directly into the Helm chart's `extraManifests`. This dynamically binds the pod IPs to the ALB Target Group without causing Terraform CRD schema validation errors at plan time.

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

These modules source foundational configurations (like VPC IDs, Subnet IDs, and Security Group IDs) dynamically from AWS Systems Manager (SSM) Parameter Store. Inter-module outputs (like Target Group ARNs or IAM Policy ARNs) are also shared via SSM Parameter paths to maintain state independence.
