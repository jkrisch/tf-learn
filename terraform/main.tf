provider "aws" {}


variable "cidr_blocks" {
    description = "cidr blocks for subnets and vpc"
    type = list(object({
        cidr_block = string
        name = string
    }))
}


#this creates a vpc in the region we defined above in our account with the ip range
resource "aws_vpc" "dev_vpc" {
    cidr_block = "10.0.0.0/16"
    tags = {
        Name: "dev-vpc",
        vpc_env: "dev"
    }
}


/*
this creates a subnet in the dev_vpc
Note:
if that resource has not been created yet or is not existin on the platform
but will be created within via this config
we can reference it via:
    - <provider>_<resource>.<resource_name>.<desired_attribute>
    - aws_vpc.dev_vpc.id gives us the id of the dev_vpc from aws_vpc which will be created in the step above
*/
resource "aws_subnet" "dev_subnet-1" {
    vpc_id = aws_vpc.dev_vpc.id
    cidr_block = var.subnet_cidr_block
    availability_zone = "eu-central-1a"
    tags = {
        Name: "dev-subnet-1"
    }
}


/*
The data declarative let's you query data and information 
from your account via the provider
The query result will be exported under the given name in this case existing_vpc
*/
data "aws_vpc" "existing_vpc" {
    default = true
}

resource "aws_subnet" "dev_subnet-2" {
    vpc_id = data.aws_vpc.existing_vpc.id
    cidr_block = "172.31.48.0/20"
    availability_zone = "eu-central-1a"
    tags = {
        Name: "default-subnet-2"
    }
}


/*
Using output we can define which values we want terraform to output at the end of a tf apply
*/

output "dev-vpc-id" {
    value = aws_vpc.dev_vpc.id
}

output "dev-subnet-id" {
    value = aws_subnet.dev_subnet-1.id
} 