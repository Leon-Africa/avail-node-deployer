# AVAIL NODE

Multi-cloud automated deployment for an [Avail](https://www.availproject.org/) full node.

NOTE: Current version deploys to AWS cloud.

# System Setup

```git clone https://github.com/Leon-Africa/avail-node.git && cd avail-node```

### Configure Credentials

We will be using an automated role to allow you to securely deploy your Avail Node to your AWS account:

- Go to [AWS Console](https://aws.amazon.com/console/) > CloudFormation > Create stack > With new resources (standard).
- Copy paste the contents of ```avail_node_role.yml``` file in this repo and follow the prompts to create the stack.
- Once deployed select the newly created stack.
- Go to the **Outputs** tab.
- Note the value of the `AvailNodeRoleArn` key.

## Docker 

Please ensure that you have [Docker](https://www.docker.com/products/docker-desktop/) installed to use the preconfigure image which will setup all the dependancies and you can deploy from the container:


````docker build --no-cache -t ubuntu_launcher .````

````docker run -it --name launcher ubuntu_launcher /bin/bash```` 



NOTE: You will deploy and access your Avail node from the Docker container.

# Deployment

Automatically deploy the infrastructure and configuration as code for a fully running Avail node with metrics and dashboards to your account from the Docker Container.


````./deploy-avail-node.sh````

NOTE: when prompted for the ````role arn```` enter the value for ````AvailNodeRoleArn```` recieved from the Cloudformation deployment.

That's it you now have a fully running Avail Node in AWS with metrics and dashboards.

### Connect to your Avail Node:

````aws ssm start-session --target instance-id````

Note: you can find your instance-id in the logs from running the ansible script [the blue color] or in the aws console.

When your ssm session starts ensure that you:

````sudo su````

and navigate to:

````cd ../../../../home````

# Explore

The logs for the node can be found under ````home/logs````

So if you want to get log data for the running Avail node: 

````tail -f logs/node/node.log````

# Metrics

Prometheus:  ````your_aws_instance_ip:9090````

Grafana: ````your_aws_instance_ip:3000```` [username: admin, password: admin] 

Note: Only accesible from the host machine you deployed from. 

# Logs

Grafana has data source setup for [Loki](https://github.com/grafana/loki) which is used to aggregate logs from the Avail node.

# Clean up

To clean up resources simply run ````terraform destroy```` from the ````terraform/aws```` directory.
