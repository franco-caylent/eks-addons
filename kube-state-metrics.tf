resource "helm_release" "kube_state_metrics" {
  count = var.enable_kube_state_metrics ? 1 : 0
  name  = "kube-state-metrics"

  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-state-metrics"
  version    = "5.6.2"
  namespace  = "kube-system"
  set {
    name  = "replicas"
    value = "2"
  }
}


