#!/bin/bash

echo "Automatically deploying the infrastructure and configuration as code for a fully running Avail Full Node with Monitoring, Logging, and Observability to your AWS account."

# Prompt user to configure AWS CLI
echo "Configure your AWS CLI:"
aws configure

# Check if AWS credentials are configured
if ! aws sts get-caller-identity &> /dev/null; then
    echo "Failed to configure AWS CLI. Please check your credentials and try again."
    exit 1
fi

# Prompt user to enter the number of nodes
while true; do
    read -p "Please enter the number of nodes to create (1-20): " number_of_nodes
    number_of_nodes=$(echo "$number_of_nodes" | xargs) # Trim any leading/trailing whitespace
    if ! [[ "$number_of_nodes" =~ ^[0-9]+$ ]]; then
        echo "Invalid input. Please enter a valid number."
    elif [ "$number_of_nodes" -lt 1 ] || [ "$number_of_nodes" -gt 20 ]; then
        echo "The number of nodes must be between 1 and 20. Please try again."
    else
        echo "Number of nodes to create: '$number_of_nodes'"
        break
    fi
done

cd terraform/aws

# Initialize Terraform
terraform init

# Generate and review Terraform plan
terraform plan -var="number_of_nodes=${number_of_nodes}"

echo "Initiating Infrastructure"
# Deploy the node infrastructure automatically answering "yes" to any prompts
yes yes | terraform apply -var="number_of_nodes=${number_of_nodes}"

echo "Wait for SSM agent"
sleep 30

cd ../../ansible

# Install Ansible dependencies
ansible-galaxy install -r requirements.yml

echo "Initiating Configuration"

# Configure the node using Ansible with the dynamic inventory
ansible-playbook -i inventory/aws_ec2.yml playbooks/avail-full-node.yml --flush-cache -vvv

echo "Avail Node Deployment complete!"
