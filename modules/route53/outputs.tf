################################################################################
# modules/route53/outputs.tf
################################################################################

output "certificate_arn" {
  description = "Validated ACM certificate ARN — passed to Ingress annotation"
  value       = aws_acm_certificate_validation.main.certificate_arn
}

output "hosted_zone_id" {
  description = "Route53 hosted zone ID"
  value       = data.aws_route53_zone.main.zone_id
}

output "app_dns_record" {
  description = "The A alias record created for the application"
  value       = aws_route53_record.app.fqdn
}

output "name_servers" {
  description = "Name servers for the hosted zone (configure at your domain registrar)"
  value       = data.aws_route53_zone.main.name_servers
}
