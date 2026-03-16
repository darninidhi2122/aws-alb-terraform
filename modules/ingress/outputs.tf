################################################################################
# Ingress Outputs
################################################################################

output "alb_dns_name" {
  description = "DNS name of the ALB created by the ingress"
  value       = kubernetes_ingress_v1.nginx.status[0].load_balancer[0].ingress[0].hostname
}

output "alb_zone_id" {
  description = "ALB hosted zone ID for us-east-1"
  value       = "Z35SXDOTRQ7X7K"
}