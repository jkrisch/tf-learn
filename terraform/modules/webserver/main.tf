resource "aws_security_group" "myapp-sg" {
    name = "myapp-sg"
    vpc_id = var.vpc_id
    
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
        values = [var.image_name]
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
    ami = data.aws_ami.latest-amazon-linux-image.image_id

    instance_type = var.instance_type

    subnet_id = var.subnet_id
    
    vpc_security_group_ids = [aws_security_group.myapp-sg.id]

    availability_zone = var.avail_zone

    associate_public_ip_address = true

    key_name = aws_key_pair.myapp-key-pair.key_name

    user_data = file("${path.module}/entrypoint.sh")

    user_data_replace_on_change = true

    tags = {
        Name: "${var.env_prefix}-server"
    }
}