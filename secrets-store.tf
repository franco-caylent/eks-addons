resource "helm_release" "secrets_store_csi_driver" {
  name = "secrets-store-csi-driver"

  repository = "https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts"
  chart      = "secrets-store-csi-driver"
  version    = "1.3.3"
  namespace  = "kube-system"
  # Sync as kubernetes secret
  set {
    name  = "syncSecret.enabled"
    value = "true"
  }
  set {
    name  = "enableSecretRotation"
    value = "false"
  }
  #depends_on = [data.http.eks_cluster_readiness]
}

resource "helm_release" "aws_secrets_manager" {
  name       = "secrets-store-aws-provider"
  repository = "https://aws.github.io/secrets-store-csi-driver-provider-aws"
  chart      = "secrets-store-csi-driver-provider-aws"
  version    = "0.3.3"
  namespace  = "kube-system"
  depends_on = [helm_release.secrets_store_csi_driver]
}
