data "aws_ami" "slacko-app"  {
    most_recent = true
    owners = ["amazon"]

    filter {
        name = "name"
        values = ["amazon*"]
    }
    
    filter {
        name = "architecture"
        values = ["x86_64"]
    }
}

data "aws_subnet" "subnet_public" {
    cidr_block = "10.0.102.0/24"    
}


data "aws_vpc" "my-vpc" {
    filter {
      name ="tag:Name"
      values = ["my-vpc"]

    } 
}


resource "aws_key_pair" "slacko-sshkey"{
    key_name = "slacko-app-key"
    public_key = file("slacko.pub")
    

}

resource "aws_instance" "slacko-app" {
    ami = data.aws_ami.slacko-app.id
    instance_type = "t2.micro"
    subnet_id = data.aws_subnet.subnet_public.id
    associate_public_ip_address = true

    tags = {
        Name = "slacko-app"
    }

    key_name = aws_key_pair.slacko-sshkey.id
    user_data = file("ec2.sh")
}

resource "aws_instance" "mongodb" {
    ami = data.aws_ami.slacko-app.id
    instance_type = "t2.small"
    subnet_id = data.aws_subnet.subnet_public.id

    tags = {
        Name = "mongodb"
    }

    key_name = aws_key_pair.slacko-sshkey.id
    user_data = file("mongodb.sh")
}    

resource "aws_security_group" "allow-slacko" {
    name = "allow_ssh_http"
    description = "allow ssh and http port"
    vpc_id = "vpc-0eb594e2572bbbda5"
      
    ingress =[
        {
        description = "Allow SSH"
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        ipv6_cidr_blocks = []
        prefix_list_ids = []
        security_groups = []
        self = null

    },
     {
        description = "Allow HTTP"
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        ipv6_cidr_blocks = []
        prefix_list_ids = []
        security_groups = []
        self = null
    }
]

    egress = [
        {
        description = "Allow all"
        from_port = 0
        to_port = 0
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        ipv6_cidr_blocks = []
        prefix_list_ids = []
        security_groups = []
        self = null
        }
]

    tags = {
        Name = "allow_ssh_http"
    }
}

resource "aws_security_group" "allow-mongodb" {
    name = "allow_mongodb"
    description = "allow Mongodb"
    vpc_id = "vpc-0eb594e2572bbbda5"

    ingress = [
        {
        description = "allow mongodb"
        from_port = 27017
        to_port = 27017
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        ipv6_cidr_blocks = []
        prefix_list_ids = []
        security_groups = []
        self = null
        }
    ]

    egress = [
        {
        description = "Allow all"
        from_port = 0
        to_port = 0
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        ipv6_cidr_blocks = []
        prefix_list_ids = []
        security_groups = []
        self = null
        }
    ]
    
    tags = {
        Name = "allow_mongodb"
    }
}

resource "aws_network_interface_sg_attachment" "mongodb-sg" {
    security_group_id = aws_security_group.allow-mongodb.id
    network_interface_id = aws_instance.mongodb.primary_network_interface_id
}

resource "aws_network_interface_sg_attachment" "slacko-sg" {
    security_group_id = aws_security_group.allow-mongodb.id
    network_interface_id = aws_instance.slacko-app.primary_network_interface_id
}

resource "aws_route53_zone" "slack_zone"{
    name = "iaac0506.com.br"

    vpc {
      vpc_id = "vpc-0eb594e2572bbbda5"
    }
}

resource "aws_route53_record" "mongodb"{
    zone_id = aws_route53_zone.slack_zone.id
    name = "mongodb.iaac0506.com.br"
    type = "A"
    ttl = "300"
    records = [aws_instance.mongodb.private_ip]
}
