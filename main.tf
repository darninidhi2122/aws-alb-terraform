################################################################################

# Root main.tf — EKS + ALB + Route53 Infrastructure

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

################################################################################

# AWS Provider

################################################################################

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

################################################################################

# Data Sources

################################################################################

data "aws_caller_identity" "current" {}

data "aws_availability_zones" "available" {}

################################################################################

# Locals

################################################################################

locals {
  cluster_name = "${var.project_name}-${var.environment}"
}

################################################################################

# VPC Module

################################################################################

module "vpc" {
  source = "./modules/vpc"

  project_name = var.project_name
  environment  = var.environment
  cluster_name = local.cluster_name

  vpc_cidr = var.vpc_cidr

  availability_zones = slice(
    data.aws_availability_zones.available.names,
    0,
    2
  )

  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

################################################################################

# EKS Cluster

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

  depends_on = [module.vpc]
}

################################################################################

# EKS Data Sources

################################################################################

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_name

  depends_on = [
    module.eks
  ]
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name

  depends_on = [
    module.eks
  ]
}

################################################################################

# Kubernetes Provider

################################################################################

provider "kubernetes" {

  host = data.aws_eks_cluster.cluster.endpoint

  cluster_ca_certificate = base64decode(
    data.aws_eks_cluster.cluster.certificate_authority[0].data
  )

  token = data.aws_eks_cluster_auth.cluster.token
}

################################################################################

# Helm Provider

################################################################################

provider "helm" {

  kubernetes {

    host = data.aws_eks_cluster.cluster.endpoint

    cluster_ca_certificate = base64decode(
      data.aws_eks_cluster.cluster.certificate_authority[0].data
    )

    token = data.aws_eks_cluster_auth.cluster.token

  }
}

################################################################################

# Kubectl Provider

################################################################################

provider "kubectl" {

  host = data.aws_eks_cluster.cluster.endpoint

  cluster_ca_certificate = base64decode(
    data.aws_eks_cluster.cluster.certificate_authority[0].data
  )

  token = data.aws_eks_cluster_auth.cluster.token

  load_config_file = false
}

################################################################################

# AWS Load Balancer Controller

################################################################################

module "alb_controller" {
  source = "./modules/alb-controller"

  cluster_name            = module.eks.cluster_name
  cluster_oidc_issuer_url = module.eks.oidc_issuer_url

  aws_account_id = data.aws_caller_identity.current.account_id
  aws_region     = var.aws_region
  vpc_id         = module.vpc.vpc_id

  depends_on = [module.eks]
}

################################################################################

# Route53 + ACM

################################################################################

module "route53" {
  source = "./modules/route53"

  domain_name = var.domain_name

  depends_on = [module.alb_controller]
}

################################################################################

# Ingress Module

################################################################################

module "ingress" {

  source = "./modules/ingress"

  domain_name         = var.domain_name
  acm_certificate_arn = module.route53.certificate_arn
  namespace           = var.namespace

  aws_account_id = data.aws_caller_identity.current.account_id
  aws_region     = var.aws_region
  vpc_id         = module.vpc.vpc_id

  cluster_name            = module.eks.cluster_name
  cluster_oidc_issuer_url = module.eks.oidc_issuer_url

  depends_on = [
    module.route53,
    module.alb_controller
  ]
}

################################################################################

# DNS Record pointing to ALB

################################################################################

resource "aws_route53_record" "app" {

  zone_id = module.route53.hosted_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = module.ingress.alb_dns_name
    zone_id                = module.ingress.alb_zone_id
    evaluate_target_health = true
  }

  depends_on = [module.ingress]
}
