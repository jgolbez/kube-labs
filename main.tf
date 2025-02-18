
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

# EKS Cluster in VPC 1
module "eks_vpc1" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.21.0" # Adding explicit version for stability

  cluster_name    = "eks-cluster-vpc1"
  cluster_version = "1.27"

  vpc_id = module.spoke_aws_1.vpc.vpc_id
  subnet_ids = [
    module.spoke_aws_1.vpc.private_subnets[0].subnet_id,
    module.spoke_aws_1.vpc.private_subnets[1].subnet_id
  ]

#  cluster_endpoint_public_access = true

  eks_managed_node_groups = {
    default = {
      min_size       = 1
      max_size       = 3
      desired_size   = 2
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
    }
  }
  #depends_on = [aws_vpc_endpoint.eks1]

  #enable_irsa = true

  # Auth configuration
  # manage_aws_auth_configmap = true
  # aws_auth_roles = []
  # aws_auth_users = [
  #   {
  #     userarn  = data.aws_caller_identity.current.arn
  #     username = "admin"
  #     groups   = ["system:masters"]
  #   }
  # ]

  # tags = {
  #   Environment = "dev"
  # }
}
# EKS Cluster in VPC 2
module "eks_vpc2" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.21.0" # Adding explicit version for stability

  cluster_name    = "eks-cluster-vpc1"
  cluster_version = "1.27"

  vpc_id = module.spoke_aws_2.vpc.vpc_id
  subnet_ids = [
    module.spoke_aws_2.vpc.private_subnets[0].subnet_id,
    module.spoke_aws_2.vpc.private_subnets[1].subnet_id
  ]
#  cluster_endpoint_public_access = false

  eks_managed_node_groups = {
    default = {
      min_size       = 1
      max_size       = 3
      desired_size   = 2
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
    }
  }
  #depends_on = [aws_vpc_endpoint.eks2]

  #  enable_irsa = true

  # Auth configuration
  #  manage_aws_auth_configmap = true
  #  aws_auth_roles = []
  #  aws_auth_users = [
  #    {
  #      userarn  = data.aws_caller_identity.current.arn
  #      username = "admin"
  #      groups   = ["system:masters"]
  #    }
  #  ]

  ##  tags = {
  #    Environment = "dev"
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

# Get AWS caller identity
# data "aws_caller_identity" "current" {}

# AWS Load Balancer Controller service account for VPC 1
#resource "kubernetes_config_map" "aws_auth_vpc1" {
#  provider = kubernetes.vpc1  
#  depends_on = [time_sleep.wait_for_vpc1]

#  metadata {
#    name      = "aws-auth"
#    namespace = "kube-system"
#  }

#  data = {
#    mapRoles = yamlencode([
#      {
#        rolearn  = module.eks_vpc1.cluster_iam_role_arn
#        username = "system:node:{{EC2PrivateDNSName}}"
#        groups = [
#          "system:bootstrappers",
#          "system:nodes"
#        ]
#      }
#    ])
#   mapUsers = yamlencode([
#      {
#        userarn  = data.aws_caller_identity.current.arn
#        username = "admin"
#        groups   = ["system:masters"]
#      }
#    ])
#  }
#}

# AWS Load Balancer Controller service account for VPC 2
#resource "kubernetes_config_map" "aws_auth_vpc2" {
#  provider = kubernetes.vpc2
#  depends_on = [time_sleep.wait_for_vpc2]

#  metadata {
#    name      = "aws-auth"
#    namespace = "kube-system"
#  }

#  data = {
#    mapRoles = yamlencode([
#      {
#        rolearn  = module.eks_vpc2.cluster_iam_role_arn
#        username = "system:node:{{EC2PrivateDNSName}}"
#        groups = [
#          "system:bootstrappers",
#          "system:nodes"
#        ]
#      }
#    ])
#    mapUsers = yamlencode([
#      {
#        userarn  = data.aws_caller_identity.current.arn
#        username = "admin"
#        groups   = ["system:masters"]
#      }
#    ])
#  }
#}

##  Load Balancer Controller IAM role for VPC1
# module "lb_role_vpc1" {
#   source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

#   role_name                              = "eks-lb-controller-vpc1"
#   attach_load_balancer_controller_policy = true

#   oidc_providers = {
#     main = {
#       provider_arn               = module.eks_vpc1.oidc_provider_arn
#       namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
#     }
#   }
# }

# # Load Balancer Controller IAM role for VPC2
# module "lb_role_vpc2" {
#   source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

#   role_name                              = "eks-lb-controller-vpc2"
#   attach_load_balancer_controller_policy = true

#   oidc_providers = {
#     main = {
#       provider_arn               = module.eks_vpc2.oidc_provider_arn
#       namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
#     }
#   }
# }

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


# AWS Load Balancer Controller for VPC1
# resource "helm_release" "aws_load_balancer_controller_vpc1" {
#   provider   = helm.vpc1
#   name       = "aws-load-balancer-controller"
#   repository = "https://aws.github.io/eks-charts"
#   chart      = "aws-load-balancer-controller"
#   namespace  = "kube-system"
#   depends_on = [module.eks_vpc1]

#   set {
#     name  = "clusterName"
#     value = module.eks_vpc1.cluster_name
#   }

#   set {
#     name  = "serviceAccount.create"
#     value = "true"
#   }

#   set {
#     name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
#     value = module.lb_role_vpc1.iam_role_arn
#   }
# }

# # AWS Load Balancer Controller for VPC2
# resource "helm_release" "aws_load_balancer_controller_vpc2" {
#   provider   = helm.vpc2
#   name       = "aws-load-balancer-controller"
#   repository = "https://aws.github.io/eks-charts"
#   chart      = "aws-load-balancer-controller"
#   namespace  = "kube-system"
#   depends_on = [module.eks_vpc2]

#   set {
#     name  = "clusterName"
#     value = module.eks_vpc2.cluster_name
#   }

#   set {
#     name  = "serviceAccount.create"
#     value = "true"
#   }

#   set {
#     name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
#     value = module.lb_role_vpc2.iam_role_arn
#   }
# }


resource "aws_vpc_endpoint" "eks1" {
  vpc_id            = module.spoke_aws_1.vpc.vpc_id
  service_name      = "com.amazonaws.us-east-2.eks"
  vpc_endpoint_type = "Interface"
  subnet_ids = [
    module.spoke_aws_1.vpc.private_subnets[0].subnet_id,
    module.spoke_aws_1.vpc.private_subnets[1].subnet_id
  ]
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
  private_dns_enabled = true
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