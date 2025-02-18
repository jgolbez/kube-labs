module "aws_transit" {
  source  = "terraform-aviatrix-modules/mc-transit/aviatrix"
  version = "2.6.0"

  cloud   = "aws"
  region  = "us-east-2"
  cidr    = "10.0.1.0/24"
  account = "aws_admin"
  ha_gw   = false
}
module "spoke_aws_1" {
  source  = "terraform-aviatrix-modules/mc-spoke/aviatrix"
  version = "1.7.1"

  cloud      = "AWS"
  name       = "eks1"
  cidr       = "10.101.0.0/16"
  region     = "us-east-2"
  account    = "aws_admin"
  transit_gw = module.aws_transit.transit_gateway.gw_name
  ha_gw      = false
}

module "spoke_aws_2" {
  source  = "terraform-aviatrix-modules/mc-spoke/aviatrix"
  version = "1.7.1"

  cloud      = "AWS"
  name       = "eks2"
  cidr       = "10.102.0.0/16"
  region     = "us-east-2"
  account    = "aws_admin"
  transit_gw = module.aws_transit.transit_gateway.gw_name
  ha_gw      = false
}

# Security groups for EKS endpoints
resource "aws_security_group" "eks_endpoint_sg1" {
  name        = "eks-endpoint-sg1"
  description = "Security group for EKS VPC1 endpoints"
  vpc_id      = module.spoke_aws_1.vpc.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.101.0.0/16"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "eks_endpoint_sg2" {
  name        = "eks-endpoint-sg2"
  description = "Security group for EKS VPC2 endpoints"
  vpc_id      = module.spoke_aws_2.vpc.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.102.0.0/16"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EKS VPC Endpoints
resource "aws_vpc_endpoint" "eks1" {
  vpc_id            = module.spoke_aws_1.vpc.vpc_id
  service_name      = "com.amazonaws.us-east-2.eks"
  vpc_endpoint_type = "Interface"
  subnet_ids = [
    module.spoke_aws_1.vpc.private_subnets[0].subnet_id,
    module.spoke_aws_1.vpc.private_subnets[1].subnet_id
  ]
  security_group_ids = [aws_security_group.eks_endpoint_sg1.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "eks2" {
  vpc_id            = module.spoke_aws_2.vpc.vpc_id
  service_name      = "com.amazonaws.us-east-2.eks"
  vpc_endpoint_type = "Interface"
  subnet_ids = [
    module.spoke_aws_2.vpc.private_subnets[0].subnet_id,
    module.spoke_aws_2.vpc.private_subnets[1].subnet_id
  ]
  security_group_ids = [aws_security_group.eks_endpoint_sg2.id]
  private_dns_enabled = true
}

# EC2 VPC Endpoints - required for node registration
resource "aws_vpc_endpoint" "ec2_vpc1" {
  vpc_id            = module.spoke_aws_1.vpc.vpc_id
  service_name      = "com.amazonaws.us-east-2.ec2"
  vpc_endpoint_type = "Interface"
  subnet_ids = [
    module.spoke_aws_1.vpc.private_subnets[0].subnet_id,
    module.spoke_aws_1.vpc.private_subnets[1].subnet_id
  ]
  security_group_ids = [aws_security_group.eks_endpoint_sg1.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ec2_vpc2" {
  vpc_id            = module.spoke_aws_2.vpc.vpc_id
  service_name      = "com.amazonaws.us-east-2.ec2"
  vpc_endpoint_type = "Interface"
  subnet_ids = [
    module.spoke_aws_2.vpc.private_subnets[0].subnet_id,
    module.spoke_aws_2.vpc.private_subnets[1].subnet_id
  ]
  security_group_ids = [aws_security_group.eks_endpoint_sg2.id]
  private_dns_enabled = true
}

# ECR VPC Endpoints - required for pulling container images
resource "aws_vpc_endpoint" "ecr_api_vpc1" {
  vpc_id            = module.spoke_aws_1.vpc.vpc_id
  service_name      = "com.amazonaws.us-east-2.ecr.api"
  vpc_endpoint_type = "Interface"
  subnet_ids = [
    module.spoke_aws_1.vpc.private_subnets[0].subnet_id,
    module.spoke_aws_1.vpc.private_subnets[1].subnet_id
  ]
  security_group_ids = [aws_security_group.eks_endpoint_sg1.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ecr_dkr_vpc1" {
  vpc_id            = module.spoke_aws_1.vpc.vpc_id
  service_name      = "com.amazonaws.us-east-2.ecr.dkr"
  vpc_endpoint_type = "Interface"
  subnet_ids = [
    module.spoke_aws_1.vpc.private_subnets[0].subnet_id,
    module.spoke_aws_1.vpc.private_subnets[1].subnet_id
  ]
  security_group_ids = [aws_security_group.eks_endpoint_sg1.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ecr_api_vpc2" {
  vpc_id            = module.spoke_aws_2.vpc.vpc_id
  service_name      = "com.amazonaws.us-east-2.ecr.api"
  vpc_endpoint_type = "Interface"
  subnet_ids = [
    module.spoke_aws_2.vpc.private_subnets[0].subnet_id,
    module.spoke_aws_2.vpc.private_subnets[1].subnet_id
  ]
  security_group_ids = [aws_security_group.eks_endpoint_sg2.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ecr_dkr_vpc2" {
  vpc_id            = module.spoke_aws_2.vpc.vpc_id
  service_name      = "com.amazonaws.us-east-2.ecr.dkr"
  vpc_endpoint_type = "Interface"
  subnet_ids = [
    module.spoke_aws_2.vpc.private_subnets[0].subnet_id,
    module.spoke_aws_2.vpc.private_subnets[1].subnet_id
  ]
  security_group_ids = [aws_security_group.eks_endpoint_sg2.id]
  private_dns_enabled = true
}

# S3 Gateway endpoint for ECR storage
# Get route tables for VPC1
data "aws_route_tables" "vpc1_private" {
  vpc_id = module.spoke_aws_1.vpc.vpc_id
}

# Get route tables for VPC2
data "aws_route_tables" "vpc2_private" {
  vpc_id = module.spoke_aws_2.vpc.vpc_id
}

resource "aws_vpc_endpoint" "s3_vpc1" {
  vpc_id            = module.spoke_aws_1.vpc.vpc_id
  service_name      = "com.amazonaws.us-east-2.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = data.aws_route_tables.vpc1_private.ids
}

resource "aws_vpc_endpoint" "s3_vpc2" {
  vpc_id            = module.spoke_aws_2.vpc.vpc_id
  service_name      = "com.amazonaws.us-east-2.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = data.aws_route_tables.vpc2_private.ids
}

# EKS Cluster in VPC 1
module "eks_vpc1" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.21.0"

  cluster_name    = "eks-cluster-vpc1"
  cluster_version = "1.27"

  vpc_id = module.spoke_aws_1.vpc.vpc_id
  subnet_ids = [
    module.spoke_aws_1.vpc.private_subnets[0].subnet_id,
    module.spoke_aws_1.vpc.private_subnets[1].subnet_id
  ]

  cluster_endpoint_public_access  = false
  cluster_endpoint_private_access = true

  eks_managed_node_groups = {
    default = {
      min_size       = 1
      max_size       = 3
      desired_size   = 2
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
      
      # Fix for_each dependency issues
      iam_role_name            = "eks-vpc1-node-group-role"
      iam_role_use_name_prefix = false
      iam_role_path            = "/"
      iam_role_description     = "EKS managed node group IAM role"
      iam_role_attach_cni_policy = true
    }
  }
  
  depends_on = [
    aws_vpc_endpoint.eks1,
    aws_vpc_endpoint.ec2_vpc1,
    aws_vpc_endpoint.ecr_api_vpc1,
    aws_vpc_endpoint.ecr_dkr_vpc1,
    aws_vpc_endpoint.s3_vpc1
  ]
}

# EKS Cluster in VPC 2
module "eks_vpc2" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.21.0"

  cluster_name    = "eks-cluster-vpc2"  # Changed from vpc1 to vpc2
  cluster_version = "1.27"

  vpc_id = module.spoke_aws_2.vpc.vpc_id
  subnet_ids = [
    module.spoke_aws_2.vpc.private_subnets[0].subnet_id,
    module.spoke_aws_2.vpc.private_subnets[1].subnet_id
  ]
  
  cluster_endpoint_public_access  = false
  cluster_endpoint_private_access = true

  eks_managed_node_groups = {
    default = {
      min_size       = 1
      max_size       = 3
      desired_size   = 2
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
      
      # Fix for_each dependency issues
      iam_role_name            = "eks-vpc2-node-group-role"
      iam_role_use_name_prefix = false
      iam_role_path            = "/"
      iam_role_description     = "EKS managed node group IAM role"
      iam_role_attach_cni_policy = true
    }
  }
  
  depends_on = [
    aws_vpc_endpoint.eks2,
    aws_vpc_endpoint.ec2_vpc2,
    aws_vpc_endpoint.ecr_api_vpc2,
    aws_vpc_endpoint.ecr_dkr_vpc2,
    aws_vpc_endpoint.s3_vpc2
  ]
}

# Time delay for cluster and node readiness
resource "time_sleep" "wait_for_vpc1" {
  depends_on = [
    module.eks_vpc1
  ]
  create_duration = "120s"
}

resource "time_sleep" "wait_for_vpc2" {
  depends_on = [
    module.eks_vpc2
  ]
  create_duration = "120s"
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
  type        = string
  description = "Aviatrix account name for AWS"
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