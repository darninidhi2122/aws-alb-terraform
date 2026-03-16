################################################################################

# AWS Load Balancer Controller Module

################################################################################

resource "aws_iam_role" "alb_controller" {
name = "${var.cluster_name}-alb-controller"

assume_role_policy = jsonencode({
Version = "2012-10-17"
Statement = [
{
Effect = "Allow"
Principal = {
Federated = "arn:aws:iam::${var.aws_account_id}:oidc-provider/${replace(var.cluster_oidc_issuer_url, "https://", "")}"
}
Action = "sts:AssumeRoleWithWebIdentity"
Condition = {
StringEquals = {
"${replace(var.cluster_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
}
}
}
]
})
}

################################################################################

# Attach AWS managed policy

################################################################################

resource "aws_iam_policy_attachment" "alb_controller_attach" {
name       = "${var.cluster_name}-alb-controller-policy"
roles      = [aws_iam_role.alb_controller.name]
policy_arn = "arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess"
}

################################################################################

# Helm Release

################################################################################

resource "helm_release" "alb_controller" {
name       = "aws-load-balancer-controller"
namespace  = "kube-system"
repository = "https://aws.github.io/eks-charts"
chart      = "aws-load-balancer-controller"

set {
name  = "clusterName"
value = var.cluster_name
}

set {
name  = "region"
value = var.aws_region
}

set {
name  = "vpcId"
value = var.vpc_id
}

set {
name  = "serviceAccount.create"
value = "true"
}

set {
name  = "serviceAccount.name"
value = "aws-load-balancer-controller"
}
}
