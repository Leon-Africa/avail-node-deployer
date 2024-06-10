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
  region = "eu-west-1"
}

# Fetch public IP address of the host machine using the ifconfig.me service
data "http" "public_ip" {
  url = "http://ifconfig.me"
}

# Create VPC
resource "aws_vpc" "avail-node-vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "avail-node-vpc"
  }
}

# Create Public Subnet
resource "aws_subnet" "avail-node-public" {
  vpc_id            = aws_vpc.avail-node-vpc.id
  availability_zone = "eu-west-1a"
  cidr_block        = "10.0.1.0/24"

  tags = {
    Name = "avail-node-public"
  }
}

# Create Private Subnet
resource "aws_subnet" "avail-node-private" {
  vpc_id            = aws_vpc.avail-node-vpc.id
  availability_zone = "eu-west-1a"
  cidr_block        = "10.0.2.0/24"

  tags = {
    Name = "avail-node-private"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.avail-node-vpc.id

  tags = {
    Name = "avail-node-igw"
  }
}

# Create Route Table
resource "aws_route_table" "avail-node-public-rt" {
  vpc_id = aws_vpc.avail-node-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

# Associate Route Table to Subnet
resource "aws_route_table_association" "avail-node" {
  subnet_id      = aws_subnet.avail-node-public.id
  route_table_id = aws_route_table.avail-node-public-rt.id
}

# Create Security Group
resource "aws_security_group" "avail-node-sg" {
  vpc_id = aws_vpc.avail-node-vpc.id

  name        = "avail-node-sg"
  description = "Security Group for Avail Full Node"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Inbound rule to allow traffic on port 9090 from the public IP of the host machine [to access Prometheus UI]
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["${data.http.public_ip.body}/32"]
  }

  # Inbound rule to allow traffic on port 3000 from the public IP of the host machine [to access Prometheus UI]
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["${data.http.public_ip.body}/32"]
  }
}

# AWS SSM Role
resource "aws_iam_instance_profile" "ssm-profile" {
  name = "EC2SSM"
  role = aws_iam_role.ssm-role.name
}

resource "aws_iam_role" "ssm-role" {
  name               = "EC2SSM"
  description        = "EC2 SSM Role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": {
    "Effect": "Allow",
    "Principal": {"Service": "ec2.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }
}
EOF

  tags = {
    Name = "avail-node"
  }
}

resource "aws_iam_role_policy_attachment" "ssm-policy" {
  role       = aws_iam_role.ssm-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "s3-policy" {
  role       = aws_iam_role.ssm-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "ec2-policy" {
  role       = aws_iam_role.ssm-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

# Create the EC2 Instance
resource "aws_instance" "avail-node" {
  ami                         = "ami-0776c814353b4814d"
  instance_type               = "t2.2xlarge"
  subnet_id                   = aws_subnet.avail-node-public.id
  availability_zone           = "eu-west-1a"
  iam_instance_profile        = aws_iam_instance_profile.ssm-profile.name
  associate_public_ip_address = true

  root_block_device {
    volume_size           = 300
    volume_type           = "gp2"
    delete_on_termination = true
  }

  vpc_security_group_ids = [
    aws_security_group.avail-node-sg.id,
  ]

  tags = {
    Terraform = "true"
    Name      = "avail-node"
  }
}

# Create EBS Volume
resource "aws_ebs_volume" "avail-node" {
  availability_zone = "eu-west-1a"
  size              = "300"
  type              = "gp2"

  tags = {
    Name = "avail-node-volume"
  }

  lifecycle {
    prevent_destroy = false
  }
}

# Attach EBS Volume
resource "aws_volume_attachment" "avail-node" {
  device_name  = "/dev/sdh"
  volume_id    = aws_ebs_volume.avail-node.id
  instance_id  = aws_instance.avail-node.id
  force_detach = false
}

# Create S3 Bucket
resource "aws_s3_bucket" "ssm-bucket" {
  bucket = "avail-node-aws-ssm-connection-playbook"

  tags = {
    Name = "SSM Connection Bucket"
  }

  lifecycle {
    prevent_destroy = false
  }
}

# Null resource to empty the S3 bucket before deletion
resource "null_resource" "empty_ssm_bucket" {
  provisioner "local-exec" {
    command = <<EOT
    aws s3 rm s3://${aws_s3_bucket.ssm-bucket.bucket} --recursive
    EOT
  }

  triggers = {
    bucket_name = "${aws_s3_bucket.ssm-bucket.bucket}"
  }

  depends_on = [aws_s3_bucket.ssm-bucket]
}
