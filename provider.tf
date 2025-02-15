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

# Add these new data source blocks after your existing configuration
data "aws_eks_cluster_auth" "cluster" {
  name = "my-eks-cluster"
}

data "aws_eks_cluster" "cluster" {
  name = "my-eks-cluster"
}

# Add the Kubernetes provider configuration after the data sources
provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}