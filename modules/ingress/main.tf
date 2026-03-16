################################################################################

# Kubernetes Ingress Module

################################################################################

resource "kubernetes_namespace" "app" {
metadata {
name = var.namespace
}
}

################################################################################

# Nginx Deployment

################################################################################

resource "kubernetes_deployment" "nginx" {

metadata {
name      = "nginx"
namespace = kubernetes_namespace.app.metadata[0].name
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
      image = "nginx:latest"

      port {
        container_port = 80
      }

    }
  }
}

}
}

################################################################################

# Service

################################################################################

resource "kubernetes_service" "nginx" {

metadata {
name      = "nginx-service"
namespace = kubernetes_namespace.app.metadata[0].name
}

spec {

selector = {
  app = "nginx"
}

port {
  port        = 80
  target_port = 80
}

type = "ClusterIP"

}
}

################################################################################

# Ingress (Creates ALB)

################################################################################

resource "kubernetes_ingress_v1" "nginx" {

metadata {

name      = "nginx-ingress"
namespace = kubernetes_namespace.app.metadata[0].name

annotations = {

  "kubernetes.io/ingress.class" = "alb"

  "alb.ingress.kubernetes.io/scheme" = "internet-facing"

  "alb.ingress.kubernetes.io/target-type" = "ip"

  "alb.ingress.kubernetes.io/listen-ports" = "[{\"HTTP\":80},{\"HTTPS\":443}]"

  "alb.ingress.kubernetes.io/certificate-arn" = var.acm_certificate_arn

  "alb.ingress.kubernetes.io/ssl-redirect" = "443"

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

}
