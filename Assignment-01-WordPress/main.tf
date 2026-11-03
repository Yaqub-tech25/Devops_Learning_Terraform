terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "eu-west-2"
}

resource "aws_vpc" "wordpress_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "WordPress-VPC"
  }
}

resource "aws_subnet" "wordpress_public_subnet" {
  vpc_id                  = aws_vpc.wordpress_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-west-2a"
  map_public_ip_on_launch = true

  tags = {
    Name = "WordPress-Public-Subnet"
  }
}

resource "aws_route_table" "wordpress_public_rt" {
  vpc_id = aws_vpc.wordpress_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.wordpress_igw.id
  }

  tags = {
    Name = "WordPress-Public-Route-Table"
  }
}

resource "aws_route_table_association" "wordpress_public_assoc" {
  subnet_id      = aws_subnet.wordpress_public_subnet.id
  route_table_id = aws_route_table.wordpress_public_rt.id
}

resource "aws_internet_gateway" "wordpress_igw" {
  vpc_id = aws_vpc.wordpress_vpc.id

  tags = {
    Name = "WordPress-IGW"
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "wordpress_sg" {
  name_prefix = "wordpress-sg-"
  description = "Security group for WordPress EC2 instance"
  vpc_id      = aws_vpc.wordpress_vpc.id

  ingress {
    description = "Allow HTTP traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "WordPress-Security-Group"
  }
}

resource "aws_instance" "wordpress" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  vpc_security_group_ids      = [aws_security_group.wordpress_sg.id]
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.wordpress_public_subnet.id

  user_data = file("${path.module}/user_data.sh")

  depends_on = [
    aws_route_table_association.wordpress_public_assoc
  ]

  tags = {
    Name = "WordPress-Server"
  }
}

