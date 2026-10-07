locals {
  labels = {
    "app.kubernetes.io/name"       = var.app_name
    "app.kubernetes.io/managed-by" = "opentofu"
  }
}

resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = var.namespace
  }
}

resource "kubernetes_deployment_v1" "this" {
  metadata {
    name      = var.app_name
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels    = local.labels
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = local.labels
    }

    template {
      metadata {
        labels = local.labels
      }

      spec {
        container {
          name  = var.app_name
          image = var.image

          port {
            name           = "http"
            container_port = var.container_port
          }

          resources {
            requests = {
              cpu    = "50m"
              memory = "32Mi"
            }
            limits = {
              memory = "128Mi"
            }
          }

          readiness_probe {
            http_get {
              path = "/"
              port = "http"
            }
            period_seconds = 5
          }

          liveness_probe {
            http_get {
              path = "/"
              port = "http"
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "this" {
  metadata {
    name      = var.app_name
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels    = local.labels
  }

  spec {
    type     = "NodePort"
    selector = local.labels

    port {
      name        = "http"
      port        = 80
      target_port = "http"
      node_port   = var.node_port
    }
  }
}

resource "kubernetes_config_map_v1" "myConfigMap" {
  metadata {
    name      = "${var.app_name}-cm"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels    = local.labels
  }


    data = {
        api_host             = "myhost:443"
    }

}