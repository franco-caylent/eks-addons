#https://karpenter.sh/docs/upgrade-guide/#upgrading-to-v0280

resource "helm_release" "karpenter_controller" {
  name = "karpenter-controller"

  repository          = "oci://public.ecr.aws/karpenter"
  chart               = "karpenter"
  version             = "v0.29.0"
  repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  repository_password = data.aws_ecrpublic_authorization_token.token.password
  namespace           = "kube-system"
  set {
    name  = "settings.aws.clusterName"
    value = var.name
  }
  set {
    name  = "logLevel"
    value = "debug"
  }
  set {
    name  = "settings.aws.clusterEndpoint"
    value = data.aws_eks_cluster.cluster.endpoint
  }
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.karpenter_role.iam_role_arn
  }
  set {
    name  = "settings.aws.defaultInstanceProfile"
    value = "karpenter_instance_profile-${var.name}"
  }
}

resource "kubectl_manifest" "karpenter_aws_node_templates_crd" {
  yaml_body = data.http.karpenter_aws_node_templates_crd.response_body
}

resource "kubectl_manifest" "karpenter_machines_crd" {
  yaml_body = data.http.karpenter_machines_crd.response_body
}

resource "kubectl_manifest" "karpenter_provisioners_crd" {
  yaml_body = data.http.karpenter_provisioners_crd.response_body
}

# The role that karpenter uses needs to have permissions on the KMS key that is used to encrypt the root volumes
module "karpenter_role" {
  source                             = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version                            = "5.22.0"
  role_name                          = "${var.name}_eks_karpenter"
  attach_karpenter_controller_policy = true
  karpenter_controller_cluster_name  = var.name
  #karpenter_tag_key                      = "karpenter.sh/discovery/${var.name}"
  role_policy_arns = {
    ebs_key = aws_iam_policy.karpenter_node_ebs_key_policy.arn
  }
  oidc_providers = {
    main = {
      provider_arn               = data.aws_iam_openid_connect_provider.eks.arn
      namespace_service_accounts = ["kube-system:karpenter-controller"]
    }
  }
}

# Tokens are not generated by default
resource "kubernetes_secret_v1" "karpenter_controller_svc_account_token" {
  metadata {
    namespace     = "kube-system"
    generate_name = true
    annotations = {
      "kubernetes.io/service-account.name" = "karpenter-controller"
    }
  }
  type = "kubernetes.io/service-account-token"
}

# Get it from https://github.com/aws/karpenter/blob/main/examples/provisioner/large-instances.yaml
resource "kubernetes_manifest" "karpenter_provisioner" {
  manifest = {
    "apiVersion" = "karpenter.sh/v1alpha5"
    "kind"       = "Provisioner"
    "metadata" = {
      "name" = "default-provider"
    }
    "spec" = {
      "consolidation" = {
        "enabled" = true
      }
      "providerRef" = {
        "name" = "default-provider"
      }
      "requirements" = [
        {
          "key"      = "karpenter.k8s.aws/instance-cpu"
          "operator" = "Gt"
          "values"   = ["3"]
        },
        {
          "key"      = "karpenter.k8s.aws/instance-memory"
          "operator" = "Gt"
          "values"   = ["8191"]
        },
        {
          "key"      = "karpenter.sh/capacity-type"
          "operator" = "In"
          "values"   = ["on-demand"]
        },
        {
          "key"      = "kubernetes.io/arch"
          "operator" = "In"
          "values"   = ["amd64"]
        },
        {
          "key"      = "karpenter.k8s.aws/instance-generation"
          "operator" = "Gt"
          "values"   = ["2"]
        },
        {
          "key"      = "karpenter.k8s.aws/instance-category"
          "operator" = "In"
          "values"   = ["c", "m", "r"]
        },
        {
          "key"      = "kubernetes.io/os"
          "operator" = "In"
          "values"   = ["linux"]
        }
      ]
    }
  }
}

resource "kubernetes_manifest" "node_template" {
  manifest = {
    "apiVersion" = "karpenter.k8s.aws/v1alpha1"
    "kind"       = "AWSNodeTemplate"
    "metadata" = {
      "name" = "default-provider"
    }
    "spec" = {
      "subnetSelector" = {
        "kubernetes.io/cluster/${var.name}" = "owned"
        "description"                       = "EKS Worker Nodes"
      }
      "securityGroupSelector" = {
        "kubernetes.io/cluster/${var.name}" = "owned"
      }
      "amiFamily" = "Bottlerocket"
      "blockDeviceMappings" = [
        {
          "deviceName" = "/dev/xvda"
          "ebs" = {
            "volumeSize"          = "2Gi"
            "volumeType"          = "gp3"
            "encrypted"           = "true"
            "kmsKeyID"            = aws_kms_key.karpenter_node_ebs_key.key_id
            "deleteOnTermination" = "true"
          }
        },
        {
          "deviceName" = "/dev/xvdb"
          "ebs" = {
            "volumeSize"          = "20Gi"
            "volumeType"          = "gp3"
            "encrypted"           = "true"
            "kmsKeyID"            = aws_kms_key.karpenter_node_ebs_key.key_id
            "deleteOnTermination" = "true"
          }
        }
      ]
      "tags" = {
        "karpenter.sh/discovery" = var.name
        "Name"                   = "karpenter-${var.name}-default-provider"
      }
    }
  }
}

resource "aws_kms_key" "karpenter_node_ebs_key" {
  description             = "Key for EBS encryption of karpenter nodes"
  enable_key_rotation     = true
  deletion_window_in_days = 7
}

resource "aws_iam_policy" "karpenter_node_ebs_key_policy" {
  name        = "karpenter_node_ebs_key_policy"
  path        = "/"
  description = "Grant Karpenter permissions to encrypt volumes"
  policy = jsonencode({
    Version = "2012-10-17" #tfsec:ignore:aws-iam-no-policy-wildcards
    Statement = [
      {
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
          "kms:CreateGrant"
        ]
        Effect   = "Allow"
        Resource = aws_kms_key.karpenter_node_ebs_key.arn
      },
    ]
  })
}
