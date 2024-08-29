module "eks-cluster-jk" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.24.0"

  cluster_name = "myapp-eks-cluster"
  #k8s version
  cluster_version = "1.30"

  #list of subnets of which we want the worker nodes started in 
  #our workloads should be scheduled in the private subnets
  #the public subnets are for external resources like loadbalancer
  #to reference these we use the outputs of the vpc module
  subnet_ids = module.my-eks-cluster-vpc.private_subnets
  vpc_id = module.my-eks-cluster-vpc.vpc_id

  #for kubectl to able to connect we need the public access
  cluster_endpoint_public_access  = true

  tags = {
    environment = "dev"
    application = "myapp"
  } 

  #to be able to see the resources add this line
  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    dev = {
        min_size = 1
        max_size = 3
        desired_size = 3

        instance_types = ["t2.small"]
    }
  }
}