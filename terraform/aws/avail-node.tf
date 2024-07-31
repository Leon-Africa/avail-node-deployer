terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-west-1"
}

# Fetch public IP address of the host machine using the ifconfig.me service
data "http" "public_ip" {
  url = "http://ifconfig.me"
}

# Create VPC
resource "aws_vpc" "avail_node_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "avail-node-vpc"
  }
}

# Create Public Subnet
resource "aws_subnet" "avail_node_public" {
  vpc_id            = aws_vpc.avail_node_vpc.id
  availability_zone = "eu-west-1a"
  cidr_block        = "10.0.1.0/24"

  tags = {
    Name = "avail-node-public"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.avail_node_vpc.id

  tags = {
    Name = "avail-node-igw"
  }
}

# Create Route Table
resource "aws_route_table" "avail_node_public_rt" {
  vpc_id = aws_vpc.avail_node_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

# Associate Route Table to Subnet
resource "aws_route_table_association" "avail_node" {
  subnet_id      = aws_subnet.avail_node_public.id
  route_table_id = aws_route_table.avail_node_public_rt.id
}

# Create Security Group
resource "aws_security_group" "avail_node_sg" {
  vpc_id = aws_vpc.avail_node_vpc.id

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

  # Inbound rule to allow traffic on port 3100 from the public IP of the host machine [to access Loki UI]
  ingress {
    from_port   = 3100
    to_port     = 3100
    protocol    = "tcp"
    cidr_blocks = ["${data.http.public_ip.body}/32"]
  }

  # Inbound rule to allow traffic on port 3000 from the public IP of the host machine [to access Grafana UI]
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["${data.http.public_ip.body}/32"]
  }
}

# AWS SSM Role
resource "aws_iam_instance_profile" "ssm_profile" {
  name = "EC2SSM"
  role = aws_iam_role.ssm_role.name
}

resource "aws_iam_role" "ssm_role" {
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

resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "s3_policy" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "ec2_policy" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

# Create EC2 Instances
resource "aws_instance" "avail_node" {
  count                     = var.number_of_nodes
  ami                       = "ami-0776c814353b4814d"
  instance_type             = "t2.2xlarge"
  subnet_id                 = aws_subnet.avail_node_public.id
  availability_zone         = "eu-west-1a"
  iam_instance_profile      = aws_iam_instance_profile.ssm_profile.name
  associate_public_ip_address = true

  root_block_device {
    volume_size           = 300
    volume_type           = "gp2"
    delete_on_termination = true
  }

  vpc_security_group_ids = [
    aws_security_group.avail_node_sg.id,
  ]

  tags = {
    Terraform = "true"
    Name      = "avail-node-${count.index + 1}"
  }
}

# Create EBS Volumes
resource "aws_ebs_volume" "avail_node" {
  count              = var.number_of_nodes
  availability_zone  = "eu-west-1a"
  size               = 300
  type               = "gp2"

  tags = {
    Name = "avail-node-volume-${count.index + 1}"
  }

  lifecycle {
    prevent_destroy = false
  }
}

# Attach EBS Volumes
resource "aws_volume_attachment" "avail_node" {
  count        = var.number_of_nodes
  device_name  = "/dev/sdh"
  volume_id    = aws_ebs_volume.avail_node[count.index].id
  instance_id  = aws_instance.avail_node[count.index].id
  force_detach = false
}

# Create S3 Bucket with unique name
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "ssm_bucket" {
  bucket = "avail-node-aws-ssm-connection-playbook-${random_id.bucket_suffix.hex}"

  tags = {
    Name = "SSM Connection Bucket"
  }

  lifecycle {
    prevent_destroy = false
  }
}

# Output the bucket name
output "ssm_bucket_name" {
  value = aws_s3_bucket.ssm_bucket.bucket
}

# Null resource to empty the S3 bucket before deletion
resource "null_resource" "empty_ssm_bucket" {
  provisioner "local-exec" {
    command = <<EOT
    aws s3 rm s3://${aws_s3_bucket.ssm_bucket.bucket} --recursive
    EOT
  }

  triggers = {
    bucket_name = "${aws_s3_bucket.ssm_bucket.bucket}"
  }

  depends_on = [aws_s3_bucket.ssm_bucket]
}
