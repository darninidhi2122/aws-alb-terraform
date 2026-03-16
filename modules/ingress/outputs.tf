################################################################################
# modules/ingress/outputs.tf
#
# The ALB DNS name is written by the ALB controller into the Ingress status
# after it provisions the load balancer. Terraform reads it here and passes
# it to the Route53 module to create the alias record.
################################################################################

output "alb_dns_name" {
  description = "ALB DNS name provisioned by the AWS Load Balancer Controller"
  value       = kubernetes_ingress_v1.nginx.status[0].load_balancer[0].ingress[0].hostname
}

output "alb_zone_id" {
  description = "Hosted zone ID for the ALB (needed for Route53 alias record)"
  # ALB hosted zone IDs are fixed per region — see AWS docs
  # https://docs.aws.amazon.com/general/latest/gr/elb.html
  value = {
    "us-east-1"      = "Z35SXDOTRQ7X7K"
    "us-east-2"      = "Z3AADJGX6KTTL2"
    "us-west-1"      = "Z368ELLRRE2KJ0"
    "us-west-2"      = "Z1H1FL5HABSF5"
    "ap-south-1"     = "ZP97RAFLXTNZK"
    "ap-southeast-1" = "Z1LMS91P8CMLE5"
    "ap-southeast-2" = "Z1GM3OXH4ZPM65"
    "ap-northeast-1" = "Z14GRHDCWA56QT"
    "eu-west-1"      = "Z32O12XQLNTSW2"
    "eu-west-2"      = "ZHURV8PSTC4K8"
    "eu-central-1"   = "Z215JYRZR1TBD5"
  }
}
