################################################################################
# Root main.tf — EKS + ALB + Route53 Full Stack
# Orchestrates: VPC → EKS → ALB Controller → Nginx App → Route53
################################################################################

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# Kubernetes & Helm providers use EKS cluster credentials
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

provider "kubectl" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
  token                  = data.aws_eks_cluster_auth.cluster.token
  load_config_file       = false
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}

data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {}

################################################################################
# Module: VPC
################################################################################
module "vpc" {
  source = "./modules/vpc"

  project_name        = var.project_name
  environment         = var.environment
  vpc_cidr            = var.vpc_cidr
  availability_zones  = slice(data.aws_availability_zones.available.names, 0, 2)
  public_subnet_cidrs = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  cluster_name        = local.cluster_name
}

################################################################################
# Module: EKS Cluster
################################################################################
module "eks" {
  source = "./modules/eks"

  cluster_name       = local.cluster_name
  kubernetes_version = var.kubernetes_version
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids

  node_instance_type = var.node_instance_type
  node_desired_size  = var.node_desired_size
  node_min_size      = var.node_min_size
  node_max_size      = var.node_max_size

  aws_account_id = data.aws_caller_identity.current.account_id
  aws_region     = var.aws_region
}

################################################################################
# Module: AWS Load Balancer Controller
################################################################################
module "alb_controller" {
  source = "./modules/alb-controller"

  cluster_name       = module.eks.cluster_name
  cluster_oidc_issuer_url = module.eks.oidc_issuer_url
  aws_account_id     = data.aws_caller_identity.current.account_id
  aws_region         = var.aws_region
  vpc_id             = module.vpc.vpc_id

  depends_on = [module.eks]
}

################################################################################
# Module: Ingress (Nginx deployment + Service + Ingress resource)
################################################################################
module "ingress" {
  source = "./modules/ingress"

  domain_name         = var.domain_name
  acm_certificate_arn = module.route53.certificate_arn
  namespace           = "default"

  depends_on = [module.alb_controller]
}

################################################################################
# Module: Route53 + ACM Certificate
################################################################################
module "route53" {
  source = "./modules/route53"

  domain_name  = var.domain_name
  alb_dns_name = module.ingress.alb_dns_name
  alb_zone_id  = module.ingress.alb_zone_id[var.aws_region]

  depends_on = [module.ingress]
}

################################################################################
# Locals
################################################################################
locals {
  cluster_name = "${var.project_name}-${var.environment}"
}
