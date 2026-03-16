################################################################################

# Variables

################################################################################

variable "cluster_name" {
description = "EKS cluster name"
type        = string
}

variable "cluster_oidc_issuer_url" {
description = "OIDC issuer URL from EKS"
type        = string
}

variable "aws_account_id" {
description = "AWS Account ID"
type        = string
}

variable "aws_region" {
description = "AWS region"
type        = string
}

variable "vpc_id" {
description = "VPC ID where ALB will be created"
type        = string
}

variable "domain_name" {
  type = string
}

variable "acm_certificate_arn" {
  type = string
}

variable "namespace" {
  type = string
}