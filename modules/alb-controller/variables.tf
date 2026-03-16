################################################################################

# Variables for ALB Controller Module

################################################################################

variable "cluster_name" {
description = "EKS cluster name"
type        = string
}

variable "cluster_oidc_issuer_url" {
description = "OIDC issuer URL from the EKS cluster"
type        = string
}

variable "aws_account_id" {
description = "AWS account ID"
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
