terraform {
  required_version = ">= 1.4"
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 4.64"
      configuration_aliases = [aws.ecr_public, aws.shared_services]
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.10.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.21.1"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14.0"
    }
  }
}
