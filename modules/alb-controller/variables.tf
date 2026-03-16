################################################################################
# modules/alb-controller/variables.tf
################################################################################

variable "cluster_name"             { type = string }
variable "cluster_oidc_issuer_url"  { type = string }
variable "aws_account_id"           { type = string }
variable "aws_region"               { type = string }
variable "vpc_id"                   { type = string }
