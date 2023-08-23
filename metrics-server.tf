resource "helm_release" "metrics_server" {
  count = var.enable_metrics_server ? 1 : 0
  name  = "metrics-server"

  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = "3.10.0"
  namespace  = "kube-system"

  set {
    name  = "replicas"
    value = "2"
  }
}


