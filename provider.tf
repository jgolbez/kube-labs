terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    aviatrix = {
      source  = "AviatrixSystems/aviatrix"
      version = "~> 3.2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9.0"
    }
  }
  
  required_version = ">= 1.0"
}

provider "aws" {
  region = "us-east-2"
}

provider "aviatrix" {
  controller_ip = var.controller_ip
  username     = var.username
  password     = var.password
}

provider "kubernetes" {
  alias                  = "vpc1"
  host                   = module.eks_vpc1.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_vpc1.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", module.eks_vpc1.cluster_name]
    command     = "aws"
  }
}

provider "kubernetes" {
  alias                  = "vpc2"
  host                   = module.eks_vpc2.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_vpc2.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", module.eks_vpc2.cluster_name]
    command     = "aws"
  }
}
