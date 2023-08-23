resource "helm_release" "loadbalancer_controller" {
  name = "aws-loadbalancer-controller"

  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.5.4"
  namespace  = "kube-system"
  set {
    name  = "clusterName"
    value = var.name
  }
  set {
    name  = "serviceAccount.create"
    value = "false"
  }
  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }
}

module "lb_role" {
  source                                 = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version                                = "5.22.0"
  role_name                              = "${var.name}_eks_lb"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = data.aws_iam_openid_connect_provider.eks.arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

resource "kubernetes_service_account" "aws_loadbalancer_controller_svc_account" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/name"      = "aws-load-balancer-controller"
      "app.kubernetes.io/component" = "controller"
    }
    annotations = {
      "eks.amazonaws.com/role-arn"               = module.lb_role.iam_role_arn
      "eks.amazonaws.com/sts-regional-endpoints" = "true"
    }
  }
}

resource "kubernetes_secret_v1" "aws_loadbalancer_controller_svc_account_token" {
  metadata {
    namespace     = "kube-system"
    generate_name = true
    annotations = {
      "kubernetes.io/service-account.name" = "aws-load-balancer-controller"
    }
  }

  type = "kubernetes.io/service-account-token"
}
