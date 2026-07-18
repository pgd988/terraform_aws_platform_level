## AWS Platform Level Services

This repository contains Terraform configurations for deploying platform-level services for the AWS account. The project is divided into separate directories, each maintaining its own independent Terraform state.

## Directory Structure

- `compute`: EC2 instance configurations (GitLab, RabbitMQ, MongoDB, Monitoring), including per-service IAM roles and EC2 instance profiles (`instance_profiles.tf`).
- `eks`: Amazon EKS cluster, managed add-ons (Pod Identity Agent, CloudWatch Observability, ADOT, cert-manager, Private CA Connector), and foundational tooling:
  - **EKS Auto Mode**: AWS automatically manages node provisioning, scaling, patching, and lifecycle using its built-in compute engine. No self-managed Karpenter, node groups, or CoreDNS add-on required.
  - **Node Monitoring**: Uses the `amazon-cloudwatch-observability` EKS managed add-on to deploy the CloudWatch Agent DaemonSet and Fluent Bit telemetry collectors across worker nodes.
  - **Private CA & ADOT Observability (`private_ca.tf`)**: Provisions a full AWS Private CA stack (`ACM Private CA`), AWS-managed `cert-manager` add-on, `aws-privateca-connector-for-kubernetes` add-on, and `AWSPCAClusterIssuer` CR for ADOT operator webhook certificates.
  - `workloads/`: All Kubernetes workloads deployed via Helm (default NGINX sink returning 403, Argo CD, Argo Rollouts, Argo Events, and AWS Load Balancer Controller k8s resources). Controlled by the `deploy_apps` feature toggle (`false` by default) to prevent connection errors during initial cluster bootstrap.
- `examples`: Reference YAML deployment examples:
  - `adot/`: Ready-to-deploy `adot-collector.yaml` (`OpenTelemetryCollector` CR with AWS X-Ray exporter) and `sample-app-deployment.yaml` (OTel SDK environment variables for X-Ray tracing without pod-level AWS IAM credentials).
  - `node-pools/`: EKS Auto Mode custom node pool examples (`nodeclass.yaml` + `nodepool.yaml`). Deploy via a dedicated Argo CD Application to create isolated node pools with taints/labels for workload-tier separation. See inline comments for pod targeting syntax and multi-pool patterns.
- `load_balancer`: Application Load Balancer with self-signed SSL/TLS termination and direct pod IP target group routing.
- `databases`: ElastiCache for Redis, conditional Amazon RDS PostgreSQL, and generic DynamoDB templates.
- `monitoring`: CloudWatch dashboards and alarms.
- `logging`: Centralized logging configurations, including a toggable feature (`exclude_log_groups = true`) that excludes high-volume log sources (such as `/aws/containerinsights/platform-cluster/performance` and `/aws/eks/platform-cluster/cluster`) from CloudWatch ingestion via IAM policy denial.
- `iam`: Cluster-level IAM resources split into `iam/eks/` — EKS cluster role (`eks-cluster-role`), EKS node role (`eks-node-role`), `eks_admins` IAM group with assumable admin role (`eks-admin-role`), and per-workload Pod Identity roles (ADOT, External Secrets, Argo CD, LBC, Private CA Connector). EC2 instance roles are managed in `compute`.

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

### 4. Deletion Protection — Variable-Controlled with Lifecycle Exception

All modules expose a `deletion_protection` variable (default: **`false`**) that controls API-level resource deletion guards across the entire stack. This makes the configs safe to deploy and tear down freely for **testing** by default, while supporting full hardening for **production** deployments.

#### What `deletion_protection = true` enables

| Module | Resource | AWS Attribute |
|---|---|---|
| `compute` | All EC2 instances | `disable_api_termination` |
| `load_balancer` | ALB, NLB | `enable_deletion_protection` |
| `databases` | RDS PostgreSQL | `deletion_protection` |
| `databases` | DynamoDB table | `deletion_protection_enabled` |

#### Enabling for a production deployment

Pass the variable at plan/apply time or via a `production.tfvars` file:

```bash
terraform apply -var="deletion_protection=true"
```

or in a `production.tfvars`:

```hcl
deletion_protection = true
```

#### ⚠️ Terraform `lifecycle { prevent_destroy }` — manual code change required

**`lifecycle { prevent_destroy = true }` cannot be controlled by a variable.** This is a hard Terraform language constraint: lifecycle arguments are evaluated at parse time, before variable resolution. No workaround exists within standard Terraform.

Resources that previously used `prevent_destroy = true` (EKS Cluster, EKS Node Group, NLB Security Group, ALB Security Group, Elastic IPs) have had those blocks **removed** from the codebase so that `terraform destroy` works freely by default.

**Before a production deployment**, you must manually add `lifecycle { prevent_destroy = true }` back into the relevant resource blocks in code:

- `eks/main.tf` → `aws_eks_cluster.main`
- `load_balancer/main.tf` → `aws_security_group.nlb_cloudflare`, `aws_security_group.alb_locked`, and `aws_eip.nlb`

Example:

```hcl
resource "aws_eks_cluster" "main" {
  # ...
  lifecycle {
    prevent_destroy = true
  }
}
```

This code change should be committed as part of a dedicated production promotion branch and code review.

### 5. EKS Auto Mode (Primary Deployment Model)
This platform deploys EKS in **Amazon EKS Auto Mode** (`enable_auto_mode = true` by default). In Auto Mode, AWS internally runs Karpenter as a managed service, automatically handling node provisioning, scaling, patching, block storage (EBS CSI), networking (VPC CNI, CoreDNS), and load balancing — without any self-managed controllers in the cluster.
- **No self-managed Karpenter**: Karpenter is handled by AWS. There are no `helm_release` or IAM role resources for Karpenter in this codebase.
- **IAM Hardening**: The `iam/eks` module conditionally attaches the four required AWS-managed policies (`AmazonEKSComputePolicy`, `AmazonEKSBlockStoragePolicy`, `AmazonEKSLoadBalancingPolicy`, `AmazonEKSNetworkingPolicy`) to `eks-cluster-role`, and `AmazonEKSWorkerNodeMinimalPolicy` + `AmazonEC2ContainerRegistryPullOnly` to `eks-node-role` when Auto Mode is active.
- **Operating System**: Worker nodes in Auto Mode exclusively use Bottlerocket OS and are fully managed by AWS without direct SSH/SSM access.

#### How to Enable EKS Auto Mode
To deploy or transition your cluster to EKS Auto Mode, enable the feature across both the `iam` and `eks` modules:

**Option 1: Using `terraform.tfvars` (Recommended)**
Add the variable to your shared `terraform.tfvars` (or environment variable file):
```hcl
enable_auto_mode = true

# Optional: Customize active Auto Mode node pools (defaults to general-purpose and system)
auto_mode_node_pools = ["general-purpose", "system"]
```
Then apply the IAM and EKS modules in sequence:
```bash
# 1. Apply IAM module first to attach required Auto Mode policies to eks-cluster-role
terraform -chdir=iam apply

# 2. Apply EKS module to enable Auto Mode compute/storage/routing and bypass self-managed controllers
terraform -chdir=eks apply
```

**Option 2: Using CLI Variable Flags**
Pass `-var="enable_auto_mode=true"` directly during plan and apply:
```bash
terraform -chdir=iam apply -var="enable_auto_mode=true"
terraform -chdir=eks apply -var="enable_auto_mode=true"
```


### 6. Static External IP Bridge (NLB Chaining to ALB)
Because AWS Application Load Balancers scale IP addresses dynamically and cannot attach static Elastic IPs directly, the `load_balancer` module implements an HCL **NLB Chaining Bridge** (`deploy_alb = true`).

A public Network Load Balancer (NLB) is provisioned with dedicated Elastic IPs (`aws_eip.nlb`) mapped across public subnets. The NLB uses `target_type = "alb"` target groups to forward TCP ports 80 and 443 directly into the Application Load Balancer. This gives external DNS providers (e.g., Cloudflare) fixed, immutable entrypoint IP addresses while preserving full ALB Layer 7 path routing and SSL termination.

### 7. Cloudflare Reverse Proxy Ingress Hardening
To prevent unauthorized origin IP scanning and bypass attacks, the public NLB entrypoint is bound to a hardened VPC Security Group (`aws_security_group.nlb_cloudflare`).

The security group decodes `load_balancer/policies/cloudflare_nlb_policy.json` during execution and restricts all inbound TCP traffic (ports 80 and 443) strictly to Cloudflare's published Reverse Proxy IPv4 CIDR ranges (AS13335). This ensures that only traffic originating from Cloudflare edge nodes can reach your load balancing stack.

### 8. Tiered Network Separation Topology
To enforce strict defense-in-depth across the platform, infrastructure resources are isolated across public and private subnet tiers:
- **Public Tier (Ingress & Admin Core)**: Hosts the Cloudflare-hardened Network Load Balancer (`aws_lb.nlb`) alongside external GitLab and Monitoring EC2 VMs.
- **Private Tier (Workloads & Data Core)**: Hosts the internal Application Load Balancer (`internal = true`), Amazon EKS cluster & worker nodes, all databases (RDS PostgreSQL, ElastiCache Redis, DynamoDB), and internal services (RabbitMQ, MongoDB VMs). EKS workloads communicate with databases directly within the private network tier without internet exposure.

### 9. Zero-Trust Security Group Chaining (Locking Mechanism)
Because all resources downstream of the NLB reside in private network tiers, strict zero-trust boundaries are enforced via inline Security Group chaining:
- **NLB Security Group (`nlb_cloudflare`)**: Allows ingress on TCP ports 80/443 strictly from Cloudflare's published Reverse Proxy IP ranges.
- **ALB Security Group (`alb_locked`)**: Allows ingress on TCP ports 80/443 strictly from the NLB Security Group (`aws_security_group.nlb_cloudflare`). Exported via SSM (`/platform/alb/security_group_id`).
- **EKS Cluster Security Group Rule (`alb_to_eks`)**: Allows ingress on application ports (80–8080) strictly from the ALB Security Group.

By chaining boundaries this way, your Kubernetes pods have zero path to be reached directly from the internet, the internal Application Load Balancer is shielded from direct IP scanning, and only validated requests processed through Cloudflare can ever hit application code.

### 10. DevOps Local `kubectl` Reachability & Assumable `eks-admin-role` Bridge
While worker nodes and application workloads run strictly within isolated private subnets, the EKS Kubernetes control plane is configured for seamless remote administration:
- **API Endpoint Accessibility**: Enabled dual endpoint reachability (`endpoint_private_access = true`, `endpoint_public_access = true`), allowing DevOps engineers to reach the cluster API securely from local workstations or office VPNs. Source IP whitelisting can be enforced via `var.admin_allowed_cidrs`.
- **Assumable Admin Role Bridge (`eks_admins`)**: Because AWS EKS Access Entries (`aws_eks_access_entry`) only evaluate identity ARNs directly present in STS tokens (`user/*` or `role/*`) and ignore IAM Groups (`group/*`), the architecture uses an assumable role pattern:
  1. The `iam` module provisions `aws_iam_role.eks_admin` (`eks-admin-role`) and grants members of `aws_iam_group.eks_admins` permission to assume it (`sts:AssumeRole`) alongside full EKS AWS administration permissions (`EKSAdminFullAccessPolicy`).
  2. The role ARN is exported to SSM (`/platform/iam/eks_admins_arn`).
  3. The `eks` module binds `eks-admin-role` directly to `AmazonEKSClusterAdminPolicy` via EKS Access Entries (`API_AND_CONFIG_MAP`).
  4. Developers in the `eks_admins` group configure their kubeconfig with `--role-arn arn:aws:iam::<account-id>:role/eks-admin-role` to transparently authenticate as `ClusterAdmin`.

### 11. IAM Ownership Split by Concern

To keep IAM resources co-located with the infrastructure that consumes them, roles and profiles are split across three modules:

| Module | IAM Resources Owned |
|---|---|
| `iam` | `eks-cluster-role` (EKS control plane trust), `eks_admins` IAM group & assumable `eks-admin-role` (`EKSAdminFullAccessPolicy`), LBC IAM policy |
| `eks` | `eks-node-role` + WorkerNode / CNI / ECR / CloudWatchAgentServerPolicy / SSM policy attachments |
| `compute` | Per-service EC2 roles & instance profiles: `gitlab`, `rabbitmq`, `mongodb`, `monitoring` |

This avoids cross-module dependencies and ensures each module is self-contained: the `eks` module declares and consumes the node role directly (`aws_iam_role.eks_node.arn`), and the `compute` module manages the full lifecycle of its EC2 instance profiles.

### 12. Full AWS Private CA PKI & ADOT Observability Stack
The platform implements a cloud-native, AWS-signed PKI and distributed tracing pipeline using **AWS Distro for OpenTelemetry (ADOT)** and **AWS Private CA**:
- **AWS Managed `cert-manager` & Private CA Connector (`eks/private_ca.tf`)**: Instead of relying on self-signed cluster CAs or third-party Helm charts, the cluster runs the official EKS `cert-manager` add-on paired with the `aws-privateca-connector-for-kubernetes` add-on. A dedicated Root `aws_acmpca_certificate_authority` is provisioned and linked via an `AWSPCAClusterIssuer` (`aws-privateca-issuer`), ensuring all internal admission webhooks (`opentelemetry-operator-system`) and cluster certificates are issued directly by AWS Private CA.
- **Two-Tier Tracing Architecture Without App Credentials**: Application pods do **not** require direct AWS IAM permissions or `xray:PutTraceSegments` credentials. Applications instrumented with the OpenTelemetry SDK export standard OTLP over internal Kubernetes DNS to the ADOT Collector (`adot-collector.opentelemetry.svc.cluster.local:4318`/`4317`). The ADOT Collector pod authenticates via EKS Pod Identity (`AWSXrayWriteOnlyAccess`) and exports batched traces to AWS X-Ray.
- **Ready-to-Deploy Reference Manifests (`examples/adot/`)**:
  - `examples/adot/adot-collector.yaml`: The `OpenTelemetryCollector` Custom Resource configured with OTLP receivers and the `awsxray` exporter.
  - `examples/adot/sample-app-deployment.yaml`: Sample deployment demonstrating the exact environment variables required on application containers (`OTEL_EXPORTER_OTLP_ENDPOINT`, `OTEL_PROPAGATORS: xray,tracecontext,b3`).

## Terraform Backend Setup (S3 & DynamoDB)

Each module uses a fully configured S3 backend defined in its `backend.tf`. The bucket, state key, DynamoDB lock table, and encryption are all hardcoded:

| Setting | Value |
|---|---|
| S3 bucket | `core-infra-terraform-state-bucket` |
| DynamoDB lock table | `core-infra-terraform-state-locks` |
| State key | `<module-name>/terraform.tfstate` |
| Encryption | `true` |

The only value supplied at init time is the **AWS region**, which is passed via `-backend-config`:

```bash
cd compute
terraform init -backend-config="region=eu-central-1"
```

> The S3 bucket and DynamoDB table are managed by a separate networking/bootstrap repository and must exist before running `terraform init` in any module here.

## Network & Foundation Dependencies

These modules source foundational configurations (like VPC IDs, Subnet IDs, and Security Group IDs) dynamically from AWS Systems Manager (SSM) Parameter Store. Inter-module outputs (like Target Group ARNs or IAM Policy ARNs) are also shared via SSM Parameter paths to maintain state independence.

## Teardown / Destroy Order

When destroying an EKS environment, always tear down **Kubernetes-level resources before the cluster itself**. The Helm and Kubernetes Terraform providers need a reachable cluster API to refresh and delete their managed resources. If the cluster is deleted first, provider connectivity fails and `terraform destroy` errors with:

```
Error: Kubernetes cluster unreachable: invalid configuration: no configuration has been provided
```

### Safe Destroy Sequence

```bash
# 1. Remove Kubernetes workloads (Argo CD, External Secrets, NGINX, etc.)
#    while the cluster API is still reachable
terraform -chdir=eks destroy -target=module.workloads

# 2. Remove base Helm charts (CloudWatch Observability, etc.)
terraform -chdir=eks destroy -target=module.charts

# 3. Destroy the EKS cluster itself (nodes are drained automatically by Auto Mode)
terraform -chdir=eks destroy -target=aws_eks_cluster.main

# 4. Destroy remaining AWS resources (ACM PCA, KMS, addons, security group rules, etc.)
terraform -chdir=eks destroy

# 5. (Optional) Destroy IAM and load balancer after EKS is gone
terraform -chdir=iam destroy
terraform -chdir=load_balancer destroy
```

### Recovery: Cluster Deleted Out of Band

If the EKS cluster was deleted manually (via AWS Console or CLI) and already removed from Terraform state, Helm/Kubernetes resources may still exist in the state file. Remove them before running `terraform destroy` to avoid the provider connectivity error:

```bash
cd eks

# List all remaining Kubernetes / Helm state entries
terraform state list | grep -E 'module\.charts|module\.workloads'

# Remove them in bulk (they are physically gone with the cluster)
terraform state list \
  | grep -E 'module\.charts|module\.workloads' \
  | xargs terraform state rm

# Now destroy remaining AWS resources cleanly
terraform destroy
```
