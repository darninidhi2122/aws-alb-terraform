################################################################################
# Root Outputs
################################################################################

output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "alb_dns_name" {
  value = module.ingress.alb_dns_name
}

output "application_url" {
  value = "https://${var.domain_name}"
}

output "kubeconfig_command" {
  value = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}