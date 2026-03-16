################################################################################
# Module: Ingress
#
# Creates inside Kubernetes:
#   1. Nginx Deployment (your application pods)
#   2. ClusterIP Service (exposes pods inside the cluster)
#   3. Ingress resource (ALB controller watches this and provisions the ALB)
#
# The annotations on the Ingress are the control plane for the ALB:
#   - scheme: internet-facing = public ALB
#   - target-type: ip = ALB routes directly to pod IPs (requires VPC CNI)
#   - certificate-arn: ARN of your ACM cert for HTTPS
#   - ssl-redirect: force HTTP → HTTPS
################################################################################

################################################################################
# Namespace (optional — using 'default' but you can change to your app ns)
################################################################################

# Using 'default' namespace here. For production, create a dedicated namespace:
# resource "kubernetes_namespace" "app" {
#   metadata { name = "my-app" }
# }

################################################################################
# Nginx Deployment
################################################################################

resource "kubernetes_deployment" "nginx" {
  metadata {
    name      = "nginx"
    namespace = var.namespace
    labels = {
      app = "nginx"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "nginx"
      }
    }

    template {
      metadata {
        labels = {
          app = "nginx"
        }
      }

      spec {
        container {
          name  = "nginx"
          image = "nginx:1.25-alpine"

          port {
            container_port = 80
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "200m"
              memory = "256Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 10
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }
        }
      }
    }
  }
}

################################################################################
# Kubernetes Service (ClusterIP)
# ALB with target-type=ip bypasses the NodePort — it routes directly to pod IPs
################################################################################

resource "kubernetes_service" "nginx" {
  metadata {
    name      = "nginx-service"
    namespace = var.namespace
  }

  spec {
    selector = {
      app = "nginx"
    }

    port {
      port        = 80
      target_port = 80
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}

################################################################################
# Ingress Resource
# The ALB controller reconciles this into a real AWS ALB
################################################################################

resource "kubernetes_ingress_v1" "nginx" {
  metadata {
    name      = "nginx-ingress"
    namespace = var.namespace
    annotations = {
      # Core: tells K8s which ingress controller handles this
      "kubernetes.io/ingress.class" = "alb"

      # ALB scheme: internet-facing = public, internal = private
      "alb.ingress.kubernetes.io/scheme" = "internet-facing"

      # target-type ip: ALB routes directly to pod IP (fastest, requires VPC CNI)
      # target-type instance: ALB → NodePort → pod (compatible with any CNI)
      "alb.ingress.kubernetes.io/target-type" = "ip"

      # Listeners: HTTP on 80 for redirect, HTTPS on 443 for real traffic
      "alb.ingress.kubernetes.io/listen-ports" = jsonencode([
        { "HTTP" : 80 },
        { "HTTPS" : 443 }
      ])

      # ACM certificate for HTTPS (Terraform passes this in from ACM module)
      "alb.ingress.kubernetes.io/certificate-arn" = var.acm_certificate_arn

      # Force all HTTP traffic to HTTPS
      "alb.ingress.kubernetes.io/ssl-redirect" = "443"

      # Health check settings
      "alb.ingress.kubernetes.io/healthcheck-path"             = "/"
      "alb.ingress.kubernetes.io/healthcheck-interval-seconds" = "15"
      "alb.ingress.kubernetes.io/healthcheck-timeout-seconds"  = "5"
      "alb.ingress.kubernetes.io/healthy-threshold-count"      = "2"
      "alb.ingress.kubernetes.io/unhealthy-threshold-count"    = "3"

      # Security: drop X-Forwarded-For header from untrusted sources
      "alb.ingress.kubernetes.io/target-group-attributes" = "stickiness.enabled=false"
    }
  }

  spec {
    rule {
      host = var.domain_name
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.nginx.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  # Wait for the ALB controller to provision the ALB and populate the status
  wait_for_load_balancer = true
}
