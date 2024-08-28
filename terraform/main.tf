provider "aws" {
    #We can set the region in the provider
    region="eu-central-1"
}


resource "aws_vpc" "myapp_vpc" {
    cidr_block = var.vpc_cidr_block
    tags = {
        Name: "${var.env_prefix}-vpc"
    }
}

#we can use modules with the module declarative
module "myapp-subnet" {
    source = "./modules/subnet"
    subnet_cidr_block = var.subnet_cidr_block
    avail_zone = var.avail_zone
    env_prefix = var.env_prefix
    vpc_id = aws_vpc.myapp_vpc.id
    default_route_table_id = aws_vpc.myapp_vpc.default_route_table_id    
}

module "myapp-webserver" {
    source = "./modules/webserver"
    avail_zone = var.avail_zone
    my_ip = var.my_ip
    env_prefix = var.env_prefix

    vpc_id = aws_vpc.myapp_vpc.id
    subnet_id = module.myapp-subnet.subnet.id

    public_key_location = var.public_key_location
    private_key_location = var.private_key_location

    instance_type = var.instance_type
    image_name = var.image_name
}

 