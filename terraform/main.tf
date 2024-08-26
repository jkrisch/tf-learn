provider "aws" {
    #We can set the region in the provider
    region="eu-central-1"
}


variable "vpc_cidr_block" {}
variable "subnet_cidr_block" {}
variable "avail_zone" {}
variable "env_prefix" {}
variable "my_ip" {}
variable "instance_type" {}
variable "public_key_location" {}
variable "private_key_location" {}

resource "aws_vpc" "myapp_vpc" {
    cidr_block = var.vpc_cidr_block
    tags = {
        Name: "${var.env_prefix}-vpc"
    }
}


resource "aws_subnet" "myapp_subnet-1" {
    vpc_id = aws_vpc.myapp_vpc.id
    cidr_block = var.subnet_cidr_block
    availability_zone = var.avail_zone
    tags = {
        Name: "${var.env_prefix}-subnet-1"
    }
}

#route table to handle traffic from and to the internet using the respective internet gateway 
/*resource "aws_route_table" "myapp-routetable-1"{
    vpc_id = aws_vpc.myapp_vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.myapp-internet_gateway-1.id
    }
    tags = {
        Name: "${var.env_prefix}-rtb"
    }
}
*/

resource "aws_internet_gateway" "myapp-internet_gateway-1"{
    vpc_id = aws_vpc.myapp_vpc.id

    tags = {
        Name: "${var.env_prefix}-igw"
    }
}

/*
resource "aws_route_table_association" "a-rtb-subnet" {
    subnet_id = aws_subnet.myapp_subnet-1.id    
    route_table_id = aws_route_table.myapp-routetable-1.id
}
*/

#Instead of creating a new route table we could also have used the default one:
resource "aws_default_route_table" "main-rtb"{
    default_route_table_id = aws_vpc.myapp_vpc.default_route_table_id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.myapp-internet_gateway-1.id
    }
    tags = {
        Name: "${var.env_prefix}-rtb"
    }
}


resource "aws_security_group" "myapp-sg" {
    name = "myapp-sg"
    vpc_id = aws_vpc.myapp_vpc.id

    #incoming (ingress) traffic rules
    ingress {
        #we could define a range - therefore it is from_ and to_
        from_port = 22
        to_port = 22

        protocol = "TCP"

        #List of IP addresses which can access the EC2 instance on specific port (22 in this case)
        cidr_blocks = [var.my_ip]
    }

    ingress {
        #we could define a range - therefore it is from_ and to_
        from_port = 8080
        to_port = 8080

        protocol = "TCP"

        #here we let any ip address through
        cidr_blocks = ["0.0.0.0/0"]
    }

    /*
        outgoing (egress traffic) rules
        might be needed in case we need to install apps via the internet (for instance apt-get install docker etc.)
        Or in case we need to pull a container image
        
        * defined ports to 0 --> we do not restrict the outgoing traffic to any specific prot
        * defining -1 for the protocol means no restriction to any protocol
        * 

    */
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]

        #allowing access to vpc endpoints
        prefix_list_ids = []
    }

    tags = {
        Name: "${var.env_prefix}-sg"
    }
}

data "aws_ami" "latest-amazon-linux-image" {
    #with most_recent you define that you always want to use the latest version
    most_recent = true

    #via owners you can filter for images from specific image creators (maybe your own)
    owners = ["amazon"]

    #using filter, you can also select images using specific search criteria
    #you can use multiple filter to narrow down your selection
    filter {
        name = "name"
        values = ["amzn2-ami-kernel-*-x86_64-gp2"]
    }

    filter {
        name = "virtualization-type"
        values = ["hvm"]
    }
}

resource "aws_key_pair" "myapp-key-pair" {
    key_name = "myapp-key"

    #we can reference the public key either via var (so we do not check it into git)
    #public_key = var.public_key

    #or using it's file location:
    public_key = file(var.public_key_location)
}

#create an EC2 instance
resource "aws_instance" "myapp-server" {
    /*
        ami stands for Amazon Machine Image
        The ami ID will change when a new version is released
        Therefore it is not a good practice to hardcode the id, but to fetch id programmatically using tf
        For this we use the data section above
    */
    ami = data.aws_ami.latest-amazon-linux-image.image_id

    #size of your machine like - t2.micro, t2.small, t2.large, etc.
    instance_type = var.instance_type


    /*
        until above are mandatory fields.
        If we do not specfiy any other paremeters, this EC2 instance would be deployed in a default vpc and default subnet.
                 
        from here on are optional parameters
    */

    subnet_id = aws_subnet.myapp_subnet-1.id    

    #we can configure multiple security groups for our ec2 instance
    vpc_security_group_ids = [aws_security_group.myapp-sg.id]

    availability_zone = var.avail_zone

    #to be able to access it via browser we need the ec2 instance to get a public ip
    associate_public_ip_address = true

    /*
        after you've created a ssh-key-pair (using the aws console) you can reference it in the tf file
        key_name = "server-key-pair"

        Instead of manually creating the key pair we can do it using tf
    */
    key_name = aws_key_pair.myapp-key-pair.key_name


    #using user_data you can run and executes scripts on the instance after it has been created
    #user_data is only executed once (on creation)
/*     user_data = <<EOF
                    #!/bin/bash
                    sudo yum update -y && sudo yum -y install docker
                    sudo systemctl start docker
                    sudo usermod -aG docker ec2-user
                    docker run -p 8080:80 nginx 
                EOF */

    #instead of having the script within the tf config file we can also reference a script file location
    #user_data = file('entrypoint.sh')
    
    #this flag guarantuees that the server is recreated everytime the script changed
    user_data_replace_on_change = true

    #instead of using user_data you can also use a remote-exec provisioner
    #the difference to user_data is instead of passing the data to aws
    #provisioner connects to the vm using ssh (in this case) using terraform
    #connection is specific to provisioner and is needed as terraform doesn't know how to connect to the vm even though it is defined here
    connection {
        type = "ssh"
        host = self.public_ip
        user = "ec2-user"
        private_key = file(var.private_key_location)
    }

    #provisioner with commands in the tf file
    /*provisioner "remote-exec" {
        inline = []
            "export ENV=dev",
            "mkdir newdir" 
        ]
    }*/


    #provisioner with commands in a file
    #the file must exist on the server, so we need to scp it before we can run it
    #for this we use the file-provisioner
    /*provisioner "file"{
        source = "entrypoint.sh"
        destination = "/home/ec2-user/entrypoint-ec2.sh"

    }
    provisioner "remote-exec"{
        inline=["/home/ec2-user/entrypoint-ec2.sh"]
    }*/

    #alternative of running script using remote-exec provisioner
    provisioner "remote-exec"{
        script="entrypoint.sh"
    }

    #the third provisioner is local-exec (so you run commands on your local machine - not the remote vm!)
    provisioner "local-exec"{
        command = "echo $self.public_ip} > output.txt"
    }


    tags = {
        Name: "${var.env_prefix}-server"
    }
}


#using output we verify or check the data selection
output "aws_ami_id" {
    value = data.aws_ami.latest-amazon-linux-image
}

output "ec2_instance_public_ip"{
    value = aws_instance.myapp-server.public_ip
}