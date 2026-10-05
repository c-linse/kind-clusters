output "namespace" {
  value = kubernetes_namespace_v1.this.metadata[0].name
}

output "deployment" {
  value = kubernetes_deployment_v1.this.metadata[0].name
}

output "url" {
  description = "Host URL, via the kind extraPortMapping for the NodePort."
  value       = "http://localhost:8080"
}
