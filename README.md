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
- `databases`: ElastiCache for Redis, conditional Amazon RDS PostgreSQL, and generic DynamoDB templates.
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

### 3. Customizable RDS Database Flags
The `databases` module supports conditional Amazon RDS PostgreSQL deployments (`deploy_rds = true`). Master user credentials are automatically generated and securely stored via AWS Secrets Manager (`manage_master_user_password = true`). 

To pass custom PostgreSQL database flags/parameters without modifying module code, supply a key-value map to the `rds_custom_parameters` variable:

```hcl
deploy_rds = true
rds_custom_parameters = {
  "shared_buffers"  = "256MB"
  "log_connections" = "1"
}
```

### 4. Critical Resource Deletion Safeguards
All core infrastructure components (Application Load Balancer, EKS Cluster & Node Groups, RDS PostgreSQL, DynamoDB tables, and EC2 VMs) are protected against accidental destruction via native AWS API termination locks or strict Terraform lifecycle guards.

**Rule of Thumb**: Once any critical component has been deployed via variable toggles, setting its deploy flag to `false` will be rejected during `apply`. To intentionally decommission a resource, you must first explicitly remove or disable its delete protection lock before attempting destruction.

### 5. Static External IP Bridge (NLB Chaining to ALB)
Because AWS Application Load Balancers scale IP addresses dynamically and cannot attach static Elastic IPs directly, the `load_balancer` module implements an HCL **NLB Chaining Bridge** (`deploy_alb = true`).

A public Network Load Balancer (NLB) is provisioned with dedicated Elastic IPs (`aws_eip.nlb`) mapped across public subnets. The NLB uses `target_type = "alb"` target groups to forward TCP ports 80 and 443 directly into the Application Load Balancer. This gives external DNS providers (e.g., Cloudflare) fixed, immutable entrypoint IP addresses while preserving full ALB Layer 7 path routing and SSL termination.

### 6. Cloudflare Reverse Proxy Ingress Hardening
To prevent unauthorized origin IP scanning and bypass attacks, the public NLB entrypoint is bound to a hardened VPC Security Group (`aws_security_group.nlb_cloudflare`).

The security group decodes `load_balancer/policies/cloudflare_nlb_policy.json` during execution and restricts all inbound TCP traffic (ports 80 and 443) strictly to Cloudflare's published Reverse Proxy IPv4 CIDR ranges (AS13335). This ensures that only traffic originating from Cloudflare edge nodes can reach your load balancing stack.

### 7. Tiered Network Separation Topology
To enforce strict defense-in-depth across the platform, infrastructure resources are isolated across public and private subnet tiers:
- **Public Tier (Ingress & Admin Core)**: Hosts the Cloudflare-hardened Network Load Balancer (`aws_lb.nlb`) alongside external GitLab and Monitoring EC2 VMs.
- **Private Tier (Workloads & Data Core)**: Hosts the internal Application Load Balancer (`internal = true`), Amazon EKS cluster & worker nodes, all databases (RDS PostgreSQL, ElastiCache Redis, DynamoDB), and internal services (RabbitMQ, MongoDB VMs). EKS workloads communicate with databases directly within the private network tier without internet exposure.

### 8. Zero-Trust Security Group Chaining (Locking Mechanism)
Because all resources downstream of the NLB reside in private network tiers, strict zero-trust boundaries are enforced via inline Security Group chaining:
- **NLB Security Group (`nlb_cloudflare`)**: Allows ingress on TCP ports 80/443 strictly from Cloudflare's published Reverse Proxy IP ranges.
- **ALB Security Group (`alb_locked`)**: Allows ingress on TCP ports 80/443 strictly from the NLB Security Group (`aws_security_group.nlb_cloudflare`). Exported via SSM (`/platform/alb/security_group_id`).
- **EKS Cluster Security Group Rule (`alb_to_eks`)**: Allows ingress on application ports (80–8080) strictly from the ALB Security Group.

By chaining boundaries this way, your Kubernetes pods have zero path to be reached directly from the internet, the internal Application Load Balancer is shielded from direct IP scanning, and only validated requests processed through Cloudflare can ever hit application code.

### 9. DevOps Local `kubectl` Reachability & `eks_admins` Group Bridge
While worker nodes and application workloads run strictly within isolated private subnets, the EKS Kubernetes control plane is configured for remote administration:
- **API Endpoint Accessibility**: Enabled dual endpoint reachability (`endpoint_private_access = true`, `endpoint_public_access = true`), allowing DevOps engineers to reach the cluster API securely from local workstations or office VPNs. Source IP whitelisting can be enforced via `var.admin_allowed_cidrs`.
- **Centralized IAM Group Binding (`eks_admins`)**: To avoid hardcoding individual user ARNs, the `iam` module creates a centralized `aws_iam_group.eks_admins` and exports its ARN to SSM (`/platform/iam/eks_admins_arn`). The `eks` module dynamically binds this group ARN directly to `AmazonEKSClusterAdminPolicy` via AWS EKS Access Entries (`API_AND_CONFIG_MAP`).

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
