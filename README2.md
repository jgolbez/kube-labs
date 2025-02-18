Instructions

Refer to Gitpod.yml to understand what packages and settings are pre-installed on this workspace and what you will need to do locally if running on another environment
You can use Terraform or EKSCTL to deploy the EKS resources, EKSCTL uses CloudFormation and Terraform is, well, Terraform.
In both cases you need to supply local environment variables (DO NOT commit secrets to Github!)
Make sure if you use a repo that you have a .gitignore file to keep from uploading secrets and tfstate (see attached to this repo for example)

Generally these steps are required to build an managed Kubernetes Cluster for a lab:

Create a lab user (or reuse a lab user already created)
Attach an IAM policy to the user that has the access to create and destroy all lab objects
Build the lab using whichever IAC you choose

Local Environment Variables - Add ENV Variables per Cloud

AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY

If using GitPod you can do this from the main page, under your Profile > User Settings > Variables
If using another dev environment, look up how to set and save environment variables locally
Terraform Deployment Steps
For deployments with VPC endpoints, follow this ordered approach to avoid dependency issues:

Deploy network infrastructure first:
bashCopyterraform apply -target=module.aws_transit -target=module.spoke_aws_1 -target=module.spoke_aws_2 -target=aws_security_group.eks_endpoint_sg1 -target=aws_security_group.eks_endpoint_sg2

Deploy VPC endpoints:
bashCopyterraform apply -target=data.aws_route_tables.vpc1_private -target=data.aws_route_tables.vpc2_private -target=aws_vpc_endpoint.eks1 -target=aws_vpc_endpoint.eks2 -target=aws_vpc_endpoint.ec2_vpc1 -target=aws_vpc_endpoint.ec2_vpc2 -target=aws_vpc_endpoint.ecr_api_vpc1 -target=aws_vpc_endpoint.ecr_dkr_vpc1 -target=aws_vpc_endpoint.s3_vpc1 -target=aws_vpc_endpoint.ecr_api_vpc2 -target=aws_vpc_endpoint.ecr_dkr_vpc2 -target=aws_vpc_endpoint.s3_vpc2

Deploy EKS clusters and remaining resources:
bashCopyterraform apply


Working with Multiple EKS Clusters
After deploying multiple clusters, configure kubectl contexts:
bashCopy# For VPC1 cluster
aws eks update-kubeconfig --region us-east-2 --name eks-cluster-vpc1 --alias eks-vpc1-context

# For VPC2 cluster
aws eks update-kubeconfig --region us-east-2 --name eks-cluster-vpc2 --alias eks-vpc2-context
Use specific context when running kubectl commands:
bashCopykubectl --context eks-vpc1-context get pods
kubectl --context eks-vpc2-context get nodes
Switch default context:
bashCopykubectl config use-context eks-vpc1-context
View available contexts:
bashCopykubectl config get-contexts
Troubleshooting Connection Issues
If nodes cannot reach the EKS control plane:

Verify VPC endpoints are properly configured with correct security groups
Check route tables are associated with S3 gateway endpoints
Ensure security groups allow traffic on port 443
Confirm EKS cluster has cluster_endpoint_private_access = true

Documentation
GitPod
EKSCTL
Terraform
AWS - Create a Lab User
AWS - Attach a Policy Directly to the User
EKS CTL Environment

Set your parameters for the clusters and nodes you want to deploy in eksctl-yaml.yml, for details on how to customize refer to documentation
The test-pods.yaml is what builds test containers inside these nodes, refer to the main eksctl-yaml.yml for details on where the pods should be deployed

Terraform Environment

The EKS modules are a lot and so is setting up the IAM for them. I've included the IAM Policy as a seperate file under iam-policy, it should give all permissions needed to build an EKS cluster, deploy pods and run kubectl commands

After the cluster is built, the outputs will include the command to run to register the created kubernetes cluster locally using AWS CLI:
For example, if you name your cluster my-eks-cluster and use us-east-2 region:
aws eks update-kubeconfig --region us-east-2 --name my-eks-cluster
