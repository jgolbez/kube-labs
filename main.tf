# Transit VPC
module "transit_vpc" {
  source = "terraform-aws-modules/vpc/aws"
  
  name = "transit-vpc"
  cidr = "10.0.1.0/24"
  
  azs             = ["us-east-2a", "us-east-2b"]
  public_subnets  = ["10.0.1.0/26", "10.0.1.64/26"]
  
  enable_dns_hostnames = true
  enable_dns_support   = true
}

# VPC 1
module "vpc_1" {
  source = "terraform-aws-modules/vpc/aws"
  
  name = "eks-vpc-1"
  cidr = "10.100.0.0/16"
  
  azs             = ["us-east-2a", "us-east-2b"]
  private_subnets = ["10.100.1.0/24", "10.100.2.0/24"]
  public_subnets  = ["10.100.101.0/24", "10.100.102.0/24"]
  
  enable_nat_gateway = true
  single_nat_gateway = true
  
  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/cluster/my-eks-cluster" = "shared"
    "kubernetes.io/role/elb"               = "1"
  }
  private_subnet_tags = {
    "kubernetes.io/cluster/my-eks-cluster" = "shared"
    "kubernetes.io/role/internal-elb"      = "1"
  }
}

# VPC 2
module "vpc_2" {
  source = "terraform-aws-modules/vpc/aws"
  
  name = "eks-vpc-2"
  cidr = "10.200.0.0/16"
  
  azs             = ["us-east-2a", "us-east-2b"]
  private_subnets = ["10.200.1.0/24", "10.200.2.0/24"]
  public_subnets  = ["10.200.101.0/24", "10.200.102.0/24"]
  
  enable_nat_gateway = true
  single_nat_gateway = true
  
  enable_dns_hostnames = true
  enable_dns_support   = true
}

# Transit Gateway
resource "aviatrix_transit_gateway" "transit_gw" {
  depends_on = [module.transit_vpc]
  
  cloud_type   = 1
  account_name = var.aws_account_name
  gw_name      = "transit-gw"
  vpc_id       = module.transit_vpc.vpc_id
  vpc_reg      = "us-east-2"
  gw_size      = "t3.medium"
  subnet       = "10.0.1.0/26"  # First public subnet CIDR
}

# Spoke Gateway for VPC 1
resource "aviatrix_spoke_gateway" "vpc1_spoke" {
  depends_on = [module.vpc_1]
  
  cloud_type   = 1
  account_name = var.aws_account_name
  gw_name      = "vpc1-spoke"
  vpc_id       = module.vpc_1.vpc_id
  vpc_reg      = "us-east-2"
  gw_size      = "t3.medium"
  subnet       = "10.100.101.0/24"  # First public subnet CIDR
}

# Spoke Gateway for VPC 2
resource "aviatrix_spoke_gateway" "vpc2_spoke" {
  depends_on = [module.vpc_2]
  
  cloud_type   = 1
  account_name = var.aws_account_name
  gw_name      = "vpc2-spoke"
  vpc_id       = module.vpc_2.vpc_id
  vpc_reg      = "us-east-2"
  gw_size      = "t3.medium"
  subnet       = "10.200.101.0/24"  # First public subnet CIDR
}

# Transit attachments
resource "aviatrix_spoke_transit_attachment" "vpc1_attachment" {
  depends_on = [
    aviatrix_transit_gateway.transit_gw,
    aviatrix_spoke_gateway.vpc1_spoke
  ]
  
  spoke_gw_name   = aviatrix_spoke_gateway.vpc1_spoke.gw_name
  transit_gw_name = aviatrix_transit_gateway.transit_gw.gw_name
}

resource "aviatrix_spoke_transit_attachment" "vpc2_attachment" {
  depends_on = [
    aviatrix_transit_gateway.transit_gw,
    aviatrix_spoke_gateway.vpc2_spoke
  ]
  
  spoke_gw_name   = aviatrix_spoke_gateway.vpc2_spoke.gw_name
  transit_gw_name = aviatrix_transit_gateway.transit_gw.gw_name
}

# EKS Cluster in VPC 1
module "eks_vpc1" {
  source = "terraform-aws-modules/eks/aws"
  
  cluster_name    = "eks-cluster-vpc1"
  cluster_version = "1.27"
  
  vpc_id     = module.vpc_1.vpc_id
  subnet_ids = module.vpc_1.private_subnets
  
  cluster_endpoint_public_access = true
  
  eks_managed_node_groups = {
    default = {
      min_size     = 1
      max_size     = 3
      desired_size = 2

      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
    }
  }

  enable_irsa = true
  
  tags = {
    Environment = "dev"
  }
}

# EKS Cluster in VPC 2
module "eks_vpc2" {
  source = "terraform-aws-modules/eks/aws"
  
  cluster_name    = "eks-cluster-vpc2"
  cluster_version = "1.27"
  
  vpc_id     = module.vpc_2.vpc_id
  subnet_ids = module.vpc_2.private_subnets
  
  cluster_endpoint_public_access = true
  
  eks_managed_node_groups = {
    default = {
      min_size     = 1
      max_size     = 3
      desired_size = 2

      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
    }
  }

  enable_irsa = true
  
  tags = {
    Environment = "dev"
  }
}

# AWS Load Balancer Controller service account for VPC 1
resource "kubernetes_config_map" "aws_auth_vpc1" {
  provider = kubernetes.vpc1  
  depends_on = [module.eks_vpc1]

  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = yamlencode([
      {
        rolearn  = module.eks_vpc1.eks_managed_node_groups["default"].iam_role_arn
        username = "system:node:{{EC2PrivateDNSName}}"
        groups = [
          "system:bootstrappers",
          "system:nodes"
        ]
      }
    ])
  }
}

# AWS Load Balancer Controller service account for VPC 2
resource "kubernetes_config_map" "aws_auth_vpc2" {
  provider = kubernetes.vpc2
  depends_on = [module.eks_vpc2]

  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = yamlencode([
      {
        rolearn  = module.eks_vpc2.eks_managed_node_groups["default"].iam_role_arn
        username = "system:node:{{EC2PrivateDNSName}}"
        groups = [
          "system:bootstrappers",
          "system:nodes"
        ]
      }
    ])
  }
}

# Load Balancer Controller IAM role for VPC1
module "lb_role_vpc1" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name                              = "eks-lb-controller-vpc1"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks_vpc1.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

# Load Balancer Controller IAM role for VPC2
module "lb_role_vpc2" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name                              = "eks-lb-controller-vpc2"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks_vpc2.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

# Variables for Aviatrix
variable "controller_ip" {
  type = string
}

variable "username" {
  type = string
}

variable "password" {
  type = string
}

variable "aws_account_name" {
  type = string
  description = "Aviatrix account name for AWS"
}

# Helm provider configuration for VPC1
provider "helm" {
  alias = "vpc1"
  kubernetes {
    host                   = module.eks_vpc1.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks_vpc1.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", module.eks_vpc1.cluster_name]
      command     = "aws"
    }
  }
}

# Helm provider configuration for VPC2
provider "helm" {
  alias = "vpc2"
  kubernetes {
    host                   = module.eks_vpc2.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks_vpc2.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", module.eks_vpc2.cluster_name]
      command     = "aws"
    }
  }
}

# AWS Load Balancer Controller for VPC1
resource "helm_release" "aws_load_balancer_controller_vpc1" {
  provider   = helm.vpc1
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  depends_on = [module.eks_vpc1, kubernetes_config_map.aws_auth_vpc1]

  set {
    name  = "clusterName"
    value = module.eks_vpc1.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.lb_role_vpc1.iam_role_arn
  }
}

# AWS Load Balancer Controller for VPC2
resource "helm_release" "aws_load_balancer_controller_vpc2" {
  provider   = helm.vpc2
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  depends_on = [module.eks_vpc2, kubernetes_config_map.aws_auth_vpc2]

  set {
    name  = "clusterName"
    value = module.eks_vpc2.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.lb_role_vpc2.iam_role_arn
  }
}
output "cluster_arn_vpc1" {
  description = "ARN of VPC1 EKS cluster"
  value       = module.eks_vpc1.cluster_arn
}

output "cluster_arn_vpc2" {
  description = "ARN of VPC2 EKS cluster"
  value       = module.eks_vpc2.cluster_arn
}

output "configure_kubectl_vpc1" {
  description = "Configure kubectl for VPC1 cluster"
  value       = "aws eks update-kubeconfig --region us-east-2 --name ${module.eks_vpc1.cluster_name}"
}

output "configure_kubectl_vpc2" {
  description = "Configure kubectl for VPC2 cluster"
  value       = "aws eks update-kubeconfig --region us-east-2 --name ${module.eks_vpc2.cluster_name}"
}

output "cluster_endpoint_vpc1" {
  value = module.eks_vpc1.cluster_endpoint
}

output "cluster_endpoint_vpc2" {
  value = module.eks_vpc2.cluster_endpoint
}