#!/bin/bash

echo "Automatically deploying the infrastructure and configuration as code for a fully running Avail Full Node with metrics, logs and dashboards to your account."

# Prompt user for Role ARN
read -p "Please enter the IAM Role ARN created by the CloudFormation template: " role_arn

# Assume the IAM role using AWS CLI
temp_role=$(aws sts assume-role --role-arn $role_arn --role-session-name AvailNodeSession)

export AWS_ACCESS_KEY_ID=$(echo $temp_role | jq -r '.Credentials.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo $temp_role | jq -r '.Credentials.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo $temp_role | jq -r '.Credentials.SessionToken')

cd terraform/aws

# Initialize Terraform
terraform init

# Generate and review Terraform plan
terraform plan

echo "Initiating Infrastructure"
# Deploy the node infrastructure automatically answering "yes" to any prompts
yes yes | terraform apply

echo "Wait for SSM agent"
sleep 30

cd ../../ansible

# Install Ansible dependencies
ansible-galaxy install -r requirements.yml

echo "Initiating Configuration"

# Configure the node using Ansible
ansible-playbook -i inventory/aws_ec2.yml playbooks/avail-node.yml --flush-cache -vvv

echo "Avail Node Deployment complete!"
