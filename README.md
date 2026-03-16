
# EKS + ALB + Route53 — Terraform Infrastructure

Full-stack Terraform code that provisions:
- **VPC** with public/private subnets, NAT Gateway, IGW
- **EKS cluster** with managed node group + OIDC provider
- **AWS Load Balancer Controller** via IRSA + Helm
- **Nginx app** with Kubernetes Deployment, Service, and Ingress
- **ACM certificate** with automatic DNS validation
- **Route53** alias record pointing to the ALB

---

## Architecture

```
User → Route53 (A alias) → ALB → K8s Service → Nginx Pods (EKS)
                 ↑
         ACM cert on HTTPS listener
```

## Directory structure

```
eks-alb-terraform/
├── main.tf                   # Root: wires all modules together
├── variables.tf              # Input variables
├── outputs.tf                # Key outputs (URL, kubeconfig cmd, etc.)
├── environments/
│   └── dev/
│       └── terraform.tfvars  # Dev environment values
└── modules/
    ├── vpc/                  # VPC, subnets, IGW, NAT, route tables
    ├── eks/                  # EKS cluster, node group, OIDC provider
    ├── alb-controller/       # IAM policy, IRSA role, Helm chart
    ├── ingress/              # Nginx deployment + Service + Ingress resource
    └── route53/              # Hosted zone, ACM cert, DNS records
```

---

## Prerequisites

```bash
# Install required CLI tools
brew install terraform awscli kubectl helm

# Configure AWS credentials
aws configure
# or use AWS SSO: aws sso login --profile my-profile

# Verify access
aws sts get-caller-identity
```

Terraform providers required (auto-installed by `terraform init`):
- `hashicorp/aws ~> 5.0`
- `hashicorp/kubernetes ~> 2.23`
- `hashicorp/helm ~> 2.11`
- `gavinbunney/kubectl ~> 1.14`

---

## Usage

### Step 1 — Configure your variables

```bash
cp environments/dev/terraform.tfvars terraform.tfvars
```

Edit `terraform.tfvars`:
```hcl
aws_region   = "ap-south-1"
project_name = "myapp"
environment  = "dev"
domain_name  = "app.yourdomain.com"   # must match your Route53 hosted zone
```

### Step 2 — Domain setup

**If you already have a Route53 hosted zone** for your root domain, the `route53` module
uses a `data` source to look it up — no changes needed.

**If you're creating a new hosted zone**, uncomment the `aws_route53_zone` resource
in `modules/route53/main.tf` and comment out the `data` source. After `terraform apply`,
copy the NS records from the `name_servers` output to your domain registrar.

### Step 3 — Deploy

```bash
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

Expected apply time: ~15–20 minutes
- EKS cluster: ~10 min
- Node group: ~3 min
- ALB provisioning: ~2 min
- ACM validation: ~1–2 min (automatic via Route53)

### Step 4 — Configure kubectl

```bash
# Use the output command directly
$(terraform output -raw kubeconfig_command)

# Verify
kubectl get nodes
kubectl get pods
kubectl get ingress
```

### Step 5 — Verify the stack

```bash
# Check ALB was provisioned
kubectl describe ingress nginx-ingress

# Check pods are healthy
kubectl get pods -l app=nginx

# Check service endpoints (should show pod IPs)
kubectl get endpoints nginx-service

# DNS check
nslookup app.yourdomain.com
dig +short app.yourdomain.com

# Full end-to-end
curl -I https://app.yourdomain.com
```

---

## Key concepts explained

### IRSA (IAM Roles for Service Accounts)
The ALB controller pod gets AWS credentials without any hardcoded keys.
The flow: K8s ServiceAccount → annotated with IAM role ARN → EKS OIDC provider
federates to AWS STS → controller gets short-lived credentials automatically.

### Subnet tags
These are **mandatory** for the ALB controller to discover which subnets to place the ALB in:
```
kubernetes.io/role/elb = 1              # public subnets → internet-facing ALB
kubernetes.io/role/internal-elb = 1     # private subnets → internal ALB
kubernetes.io/cluster/<name> = shared   # tells K8s these subnets belong to the cluster
```

### Target type: IP vs Instance
- `ip` — ALB routes directly to pod IPs. Requires AWS VPC CNI (default in EKS).
  Faster, no NodePort hop, supports pod-level health checks.
- `instance` — ALB routes to NodePort on the EC2 node, then kube-proxy forwards
  to the pod. Works with any CNI but adds a network hop.

### ALB zone IDs
When creating a Route53 alias record pointing to an ALB, you need the ALB's
*hosted zone ID* — a fixed, per-region value published by AWS. It is **not**
your Route53 hosted zone ID. The `ingress` module contains a map of these values.

---

## Troubleshooting

### ALB not provisioned after applying Ingress

```bash
# Check controller logs
kubectl logs -n kube-system \
  -l app.kubernetes.io/name=aws-load-balancer-controller \
  --tail=50

# Common causes:
# 1. Missing subnet tags → add kubernetes.io/role/elb=1 to public subnets
# 2. IRSA misconfiguration → check the IAM role trust policy OIDC condition
# 3. Controller not running → kubectl get pods -n kube-system
```

### Certificate stuck in PENDING_VALIDATION

```bash
aws acm describe-certificate \
  --certificate-arn <arn> \
  --query 'Certificate.DomainValidationOptions'

# Verify the CNAME record exists in Route53
aws route53 list-resource-record-sets \
  --hosted-zone-id <zone-id> \
  --query "ResourceRecordSets[?Type=='CNAME']"
```

### Pods not receiving traffic

```bash
# Check target group health in the ALB
aws elbv2 describe-target-health \
  --target-group-arn <arn>

# Check security groups allow traffic from ALB to nodes on port range 30000-32767
# (or directly to pod IPs if using target-type=ip)
```

### DNS not resolving

```bash
# Check NS records match your registrar
aws route53 get-hosted-zone --id <zone-id>

# DNS propagation can take up to 48h for new NS records at a registrar
# Use a global DNS checker: https://dnschecker.org
```

---

## Tear down

```bash
terraform destroy
```

Note: If the ALB was created by the K8s controller (not directly by Terraform),
it may not be destroyed by `terraform destroy`. To be safe, delete the Ingress
resource first so the controller cleans up the ALB:

```bash
kubectl delete ingress nginx-ingress
# Wait ~1 minute for ALB to be deleted
terraform destroy
```

---

## Extending this setup

### Add more services behind the same ALB
Add path or host rules to the Ingress in `modules/ingress/main.tf`:
```hcl
rule {
  host = "api.yourdomain.com"
  http {
    path {
      path      = "/"
      path_type = "Prefix"
      backend {
        service {
          name = "api-service"
          port { number = 8080 }
        }
      }
    }
  }
}
```

### Remote state (recommended for teams)
Add to `main.tf`:
```hcl
terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "eks-alb/dev/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
```

### Cluster Autoscaler
The node group is configured with min/max/desired. To enable autoscaling,
deploy the Cluster Autoscaler Helm chart pointing at this node group.
The node group already has the required `k8s.io/cluster-autoscaler/enabled` tag.
=======
# aws-alb-terraform
8a025467b7499bca4b9b9bea35a8696bdcf0cc64
