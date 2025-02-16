# Instructions
- Refer to Gitpod.yml to understand what packages and settings are pre-installed on this workspace and what you will nee dto do locally if running on another environment
- You can use Terraform or EKSCTL to deploy the EKS resources, EKSCTL uses CloudFormation and Terraform is, well, Terraform. 
- In both cases you need to supply local environment variables (DO NOT commit secrets to Github!)
- Make sure if you use a repo that you have a .gitignore file to keep from uploading secrets and tfstate (see attached to this repo for example)

Generally these steps are required to build an managed Kubernetes Cluster for a lab:
1. Create a lab user (or reuse a lab user already created)
2. Attach an IAM policy to the user that has the access to create and destroy all lab objects
3. Build the lab using whichever IAC you choose


## Local Environment Variables - Add ENV Variables per Cloud
- AWS_ACCESS_KEY_ID
- AWS_SECRET_ACCESS_KEY

If using GitPod you can do this from the main page, under your Profile > User Settings > Variables
If using another dev environment, look up how to set and save environment variables locally

## Documentation
[GitPod](https://gitpod.io)

[EKSCTL](https://eksctl.io)

[Terraform](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_cluster)

[AWS - Create a Lab User](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_users_create.html)

[AWS - Attach a Policy Directly to the User](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_users_change-permissions.html)


## EKS CTL Environment
- Set your parameters for the clusters and nodes you want to deploy in eksctl-yaml.yml, for details on how to customize refer to documentation
- The test-pods.yaml is what builds test containers inside these nodes, refer to the main eksctl-yaml.yml for details on where the pods should be deployed


## Terraform Environment
- The EKS modules are a lot and so is setting up the IAM for them. I've included the IAM Policy as a seperate file under iam-policy, it should give all permissions needed to build an EKS cluster, deploy pods and run kubectl commands

After the cluster is built, the outputs will include the command to run to register the created kubernetes cluster locally using AWS CLI:

For example, if you name your cluster my-eks-cluster and use us-east-2 region:
aws eks update-kubeconfig --region us-east-2 --name my-eks-cluster


