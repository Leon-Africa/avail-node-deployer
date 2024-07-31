#!/bin/bash

echo "Automatically deploying the infrastructure and configuration as code for a fully running avail Node with Monitoring, Logging, and Observability to your AWS account."

# Prompt user to configure AWS CLI
echo "setting region to eu-west-1 and output to json"
aws configure set region eu-west-1
aws configure set output json

echo "Configuring the AWS CLI - please enter the values as per prompts:"
echo "The access and secrect key are on the outputs tab for the Cloudformation Stack"
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

# Save the SSM bucket name to a file
terraform output -raw ssm_bucket_name > ../../ansible/ssm_bucket_name.txt

echo "Wait for SSM agent"
sleep 30

cd ../../ansible

# Install Ansible dependencies
ansible-galaxy install -r requirements.yml

echo "Initiating Configuration"

# Configure the node using Ansible with the dynamic inventory
AWS_PROFILE=default ansible-playbook -i inventory/aws_ec2.yml playbooks/avail-full-node.yml --extra-vars "ssm_bucket_name=$(cat ssm_bucket_name.txt)" --flush-cache -vvv

echo "Avail Node Deployment complete!"
