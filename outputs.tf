################################################################################
# Root outputs.tf
################################################################################

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = module.eks.cluster_endpoint
  sensitive   = true
}

output "kubeconfig_command" {
  description = "Run this to configure kubectl locally"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "alb_dns_name" {
  description = "ALB DNS name (before Route53 alias resolves)"
  value       = module.ingress.alb_dns_name
}

output "app_url" {
  description = "Application URL via Route53"
  value       = "https://${var.domain_name}"
}

output "certificate_arn" {
  description = "ACM certificate ARN"
  value       = module.route53.certificate_arn
}

output "name_servers" {
  description = "Hosted zone NS records — point your registrar here if using a new zone"
  value       = module.route53.name_servers
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}
