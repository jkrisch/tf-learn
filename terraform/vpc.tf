provider "aws" {
    region = "eu-central-1"
}
variable vpc_cidr_block {}
variable private_subnet_cidr_blocks {}
variable public_subnet_cidr_blocks {}

data "aws_availability_zones" "azs" {}

module "my-eks-cluster-vpc"{
    source = "terraform-aws-modules/vpc/aws"
    version = "5.1.2"

    name = "my-eks-cluster-vpc"
    cidr = var.vpc_cidr_block

    private_subnets = var.private_subnet_cidr_blocks
    public_subnets = var.public_subnet_cidr_blocks

    #to define the azs where the private and public subnets should be distributed to we can use the azs parameter
    azs = data.aws_availability_zones.azs.names

    #the default is one NAT gateway per subnet
    enable_nat_gateway = true

    #all private subnets will route their interenet traffic through this single NAT gateway
    single_nat_gateway = true

    #when ec2 instance is create it will also get assigned public and private dns names (additionally to their ip addresses)
    enable_dns_hostnames = true

    #so far we used tags to label our resources, e.g. giving it a name, or definined the env
    #one of eks main components is cloud controller manager (c-c-m)
    #orchestrates connecting to the VPCs, connecting to the subnets, connecting to worker nodes
    #in our aws account
    #it therefore needs to know which resources to talkt to, which vpc, subnet should be used etc.
    #these tags are there to tell the c-c-m which vpc, private, public subnets to use
    tags = {
        "kubernetes.io/cluster/myapp-eks-cluster" = "shared"
    }

    #for public and private subnets there is another tag which is needed
    #this tells aws to deploy the lb in the respective subnets
    #and kubernetes also needs to know in which subnet of those is the public lb (accessible from outside)
    public_subnet_tags = {
        "kubernetes.io/cluster/myapp-eks-cluster" = "shared"
        "kubernetes.io/role/elb" = 1
    }

    private_subnet_tags = {
        "kubernetes.io/cluster/myapp-eks-cluster" = "shared"
        "kubernets.io/role/internal-elb" = 1
    }
} 