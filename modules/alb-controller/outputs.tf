################################################################################

# Outputs for AWS Load Balancer Controller Module

################################################################################

output "alb_controller_role_arn" {
description = "IAM Role ARN used by AWS Load Balancer Controller"
value       = aws_iam_role.alb_controller.arn
}

output "alb_controller_role_name" {
description = "IAM Role name for AWS Load Balancer Controller"
value       = aws_iam_role.alb_controller.name
}

output "helm_release_name" {
description = "Helm release name of AWS Load Balancer Controller"
value       = helm_release.alb_controller.name
}

output "helm_release_namespace" {
description = "Namespace where AWS Load Balancer Controller is installed"
value       = helm_release.alb_controller.namespace
}
