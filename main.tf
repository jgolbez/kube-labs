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

# EKS Cluster
module "eks" {
  source = "terraform-aws-modules/eks/aws"
  
  cluster_name    = "my-eks-cluster"
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

# Load Balancer Controller IAM role
module "lb_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name                              = "eks-lb-controller"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

# Outputs
output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_certificate_authority_data" {
  value = module.eks.cluster_certificate_authority_data
}

output "vpc_1_public_subnets" {
  value = module.vpc_1.public_subnets
}

output "configure_kubectl" {
  description = "Configure kubectl: Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region us-east-2 --name ${module.eks.cluster_name}"
}