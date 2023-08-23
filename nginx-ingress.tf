resource "helm_release" "nginx_ingress_controller" {
  count            = var.enable_nginx_ingress ? 1 : 0
  name             = "nginx-ingress-controller"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = "4.6.1"
  namespace        = "nginx-ingress"
  create_namespace = true
  #depends_on = [data.http.eks_cluster_readiness]
  # Docs: https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.2/guide/service/annotations/
  # AWS Loadbalancer Configuration
  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"
    value = "nlb"
  }
  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-backend-protocol"
    value = "tcp"
  }
  # Set to true to enable cross-zone-load-balancing.
  # With multiple replicas of the ingress pods running in different AZs this should not be necessary.
  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-cross-zone-load-balancing-enabled"
    value = "true"
  }
  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-internal"
    value = "true"
  }
  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-scheme"
    value = "internal"
  }
  # The name in for the NLB. AWS ELB name has max character length of 32
  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-name"
    value = "${var.name}-ingress-cntlr"
  }
  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-target-group-attributes"
    value = "preserve_client_ip.enabled=false"
  }
  # Internal Configuration
  set {
    name  = "controller.replicaCount"
    value = "2"
  }
  # We need the aws lb controller, otherwise the in-tree controller will ignore the lb-name annotation and DNS will not work
  depends_on = [helm_release.loadbalancer_controller]
}
