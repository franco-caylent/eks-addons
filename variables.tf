variable "name" {
  description = "Name of the EKS Cluster"
  type        = string
}

variable "enable_nginx_ingress" {
  description = "The nginx ingress controller"
  default     = true
  type        = bool
}

variable "enable_metrics_server" {
  description = "Enable metrics server"
  default     = true
  type        = bool
}

variable "enable_kube_state_metrics" {
  description = "Enable kube metrics server"
  type        = bool
  default     = true
}
