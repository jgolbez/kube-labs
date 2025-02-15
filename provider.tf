terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
  
  required_version = ">= 1.0"
}

provider "aws" {
  region = "us-east-2"
  
  # AWS credentials will be pulled from environment variables:
  # AWS_ACCESS_KEY_ID
  # AWS_SECRET_ACCESS_KEY
  # AWS_DEFAULT_REGION
}
# This is our default provider configuration, which will be used for any
# kubernetes resources that don't explicitly specify a provider
provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      data.aws_eks_cluster.cluster.name
    ]
  }
}

# Add these data sources at the end of your provider.tf file
data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_name
  
  depends_on = [
    module.eks
  ]
}
