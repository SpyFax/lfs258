terraform {
  backend "http" {

  }
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region     = "ap-southeast-2"
  access_key = var.access_key
  secret_key = var.secret_key
}

# Create a VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

# Internet gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

# Public Route Table
resource "aws_route_table" "main_public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}
# DMZ
resource "aws_subnet" "dmz" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
}

# Route Table Assoc for DMZ
resource "aws_route_table_association" "dmz" {
  subnet_id      = aws_subnet.dmz.id
  route_table_id = aws_route_table.main_public.id
}

# EC2

data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # Canonical
}

# EC2 instance
resource "aws_instance" "main" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.large"
  vpc_security_group_ids      = [aws_security_group.base.id]
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.dmz.id
  key_name                    = var.ssh_key_name
  root_block_device {
    volume_size = 30
  }
  provisioner "local-exec" {
    command = "ssh-keygen -R '${self.public_ip}'"
  }
}
resource "aws_instance" "worker" {
  count                       = 2
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.large"
  vpc_security_group_ids      = [aws_security_group.base.id]
  subnet_id                   = aws_subnet.dmz.id
  key_name                    = var.ssh_key_name
  associate_public_ip_address = true
  provisioner "local-exec" {
    command = "ssh-keygen -R '${self.public_ip}'"
  }
}

resource "aws_security_group" "base" {
  name = "Base SG"

  # Outbound HTTPS
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound HTTP
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.1.0/24"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.1.0/24"]
  }
  # Allow inbound SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    self        = false
  }

  vpc_id = aws_vpc.main.id

}
# Elastic IP
resource "aws_eip" "main_eip" {
  domain = "vpc"
}

resource "aws_eip_association" "main_eip_assoc" {
  instance_id   = aws_instance.main.id
  allocation_id = aws_eip.main_eip.id
}

