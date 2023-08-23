# Make sure the name is the name of the EKS cluster
data "aws_eks_cluster" "cluster" {
  name = var.name
}

data "aws_iam_openid_connect_provider" "eks" {
  url = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}

data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.ecr_public
}

# Upload new CRDs to Artifactory under generic-local/karpenter/$version/crds/$crd_name.yaml as part of version upgrades
data "http" "karpenter_aws_node_templates_crd" {
  # original source: https://raw.githubusercontent.com/aws/karpenter/v0.29.0/pkg/apis/crds/karpenter.k8s.aws_awsnodetemplates.yaml
  url = "https://artifactory.sigfig.us:443/artifactory/generic-local/karpenter/v0.29.0/crds/karpenter.k8s.aws_awsnodetemplates.yaml"
}

data "http" "karpenter_machines_crd" {
  # original source: https://raw.githubusercontent.com/aws/karpenter/v0.29.0/pkg/apis/crds/karpenter.sh_machines.yaml
  url = "https://artifactory.sigfig.us:443/artifactory/generic-local/karpenter/v0.29.0/crds/karpenter.sh_machines.yaml"
}

data "http" "karpenter_provisioners_crd" {
  # original source: https://raw.githubusercontent.com/aws/karpenter/v0.29.0/pkg/apis/crds/karpenter.sh_provisioners.yaml
  url = "https://artifactory.sigfig.us:443/artifactory/generic-local/karpenter/v0.29.0/crds/karpenter.sh_provisioners.yaml"
}
