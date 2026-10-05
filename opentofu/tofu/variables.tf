variable "kubeconfig_path" {
  description = "Path to the kubeconfig file."
  type        = string
  default     = "~/.kube/config"
}

variable "kube_context" {
  description = "Kubeconfig context to deploy into."
  type        = string
  default     = "kind-opentofu"
}

variable "namespace" {
  description = "Namespace for the demo app."
  type        = string
  default     = "demo"
}

variable "app_name" {
  description = "Name of the deployment / service."
  type        = string
  default     = "hello"
}

variable "image" {
  description = "Container image to run."
  type        = string
  default     = "nginx:1.29-alpine"
}

variable "replicas" {
  description = "Number of pod replicas."
  type        = number
  default     = 2
}

variable "container_port" {
  description = "Port the container listens on."
  type        = number
  default     = 80
}

variable "node_port" {
  description = "NodePort to expose the app on. Must match kind-config.yaml (30080 -> localhost:8080)."
  type        = number
  default     = 30080
}
