# ═══════════════════════════════════════════════════════════════
#  GRAFANA INGRESS (Acceso público a Grafana)
# ═══════════════════════════════════════════════════════════════
#
# Ingress opcional para acceder a Grafana desde internet.
# Si no deseas acceso público, elimina este archivo o no lo apliques.
#

resource "kubernetes_ingress_v1" "grafana" {
  depends_on = [time_sleep.wait_for_prometheus_stack]

  metadata {
    name      = "grafana-ingress"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    annotations = {
      # AWS Load Balancer Controller
      "kubernetes.io/ingress.class" = "alb"
      "alb.ingress.kubernetes.io/scheme"      = "internet-facing"
      "alb.ingress.kubernetes.io/target-type" = "ip"
      
      # Health checks (el path / funciona con Grafana)
      "alb.ingress.kubernetes.io/healthcheck-path"                = "/"
      "alb.ingress.kubernetes.io/healthcheck-interval-seconds"    = "30"
      "alb.ingress.kubernetes.io/healthcheck-timeout-seconds"     = "5"
      "alb.ingress.kubernetes.io/healthy-threshold-count"         = "2"
      "alb.ingress.kubernetes.io/unhealthy-threshold-count"       = "2"
    }
  }

  spec {
    rule {
      http {
        path {
          path      = "/*"
          path_type = "Prefix"
          backend {
            service {
              name = "kube-prometheus-stack-grafana"
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

# Output del ALB de Grafana
output "grafana_alb_url" {
  description = "URL del ALB para acceder a Grafana"
  value       = try(kubernetes_ingress_v1.grafana.status[0].load_balancer[0].ingress[0].hostname, "")
}

