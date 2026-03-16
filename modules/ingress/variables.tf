################################################################################
# modules/ingress/variables.tf
################################################################################

variable "domain_name"          { type = string }
variable "acm_certificate_arn"  { type = string }
variable "namespace"            { type = string; default = "default" }
