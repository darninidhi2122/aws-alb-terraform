################################################################################
# Module: Route53 + ACM
#
# Creates:
#   1. Route53 hosted zone (or looks up existing)
#   2. ACM certificate with DNS validation
#   3. Route53 CNAME record for ACM validation
#   4. Route53 A record (alias) pointing to the ALB
#
# Flow:
#   Route53 hosted zone
#     └── A alias record → ALB DNS name  (user traffic)
#     └── CNAME record   → ACM validation (proves domain ownership to ACM)
#   ACM certificate → attached to ALB HTTPS listener (via Ingress annotation)
################################################################################

locals {
  # Extract the root domain from the full domain name
  # e.g. "app.example.com" → "example.com"
  root_domain = join(".", slice(split(".", var.domain_name), 1, length(split(".", var.domain_name))))
}

################################################################################
# Route53 Hosted Zone
# Use data source if the zone already exists; create if it doesn't
################################################################################

# Option A: Look up an existing hosted zone (comment out if creating new)
data "aws_route53_zone" "main" {
  name         = local.root_domain
  private_zone = false
}

# Option B: Create a new hosted zone (uncomment if you don't have one yet)
# resource "aws_route53_zone" "main" {
#   name = local.root_domain
# }

################################################################################
# ACM Certificate
################################################################################

resource "aws_acm_certificate" "main" {
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${local.root_domain}"]   # wildcard for flexibility
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

################################################################################
# ACM DNS Validation Record
# ACM gives you a CNAME record to prove you own the domain.
# Adding it to Route53 lets ACM validate automatically.
################################################################################

resource "aws_route53_record" "acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.main.zone_id
}

# Wait for ACM certificate validation to complete before outputting the ARN
resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for record in aws_route53_record.acm_validation : record.fqdn]
}

################################################################################
# Route53 A Record — Alias to ALB
#
# Why alias and not CNAME?
#   - Alias records are free (CNAMEs cost per query)
#   - Alias works at the zone apex (yourdomain.com — CNAME can't do this)
#   - AWS automatically updates the IPs when the ALB scales or changes
#   - EvaluateTargetHealth: Route53 won't route to an unhealthy ALB
################################################################################

resource "aws_route53_record" "app" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}
