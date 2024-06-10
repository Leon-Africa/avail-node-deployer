#!/bin/bash

echo "Automatically deploying the infrastructure and configuration as code for a fully running Avail Full Node with Monitoring, Logging and Observability to your AWS account."

# Prompt user to configure AWS CLI
echo "Configure your AWS CLI:"
aws configure

# Check if AWS credentials are configured
if ! aws sts get-caller-identity &> /dev/null; then
    echo "Failed to configure AWS CLI. Please check your credentials and try again."
    exit 1
fi

# Prompt user to enter the node name, ensure it's not empty
while true; do
    read -p "Please enter the node name for the Avail Full Node: " node_name
    node_name=$(echo "$node_name" | xargs) # Trim any leading/trailing whitespace
    if [ -z "$node_name" ]; then
        echo "Node name cannot be empty. Please try again."
    else
        echo "Node name entered: '$node_name'" # Debug output
        break
    fi
done

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

# Configure the node using Ansible with the given node name
ansible-playbook -i inventory/aws_ec2.yml playbooks/avail-full-node.yml --flush-cache -vvv -e "node_name=${node_name}"

echo "Avail Node Deployment complete!"
