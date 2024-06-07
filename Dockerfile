# Use the Ubuntu minimal image
FROM ubuntu:22.04

# Set noninteractive mode
ENV DEBIAN_FRONTEND=noninteractive

# Install necessary packages
RUN apt-get update && \
    apt-get install -y \
    git \
    python3-pip \
    unzip \
    wget \
    gnupg \
    software-properties-common \
    curl \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Install Git
RUN echo "Installing Git" && \
    apt-get install -y git 

# Install Ansible and dependencies
RUN echo "Installing Ansible" && \
    curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py && \
    python3 get-pip.py --user && \
    python3 -m pip install --user ansible && \
    python3 -m pip install --user ansible-core && \
    echo 'export PATH=$HOME/.local/bin:$PATH' >> $HOME/.bashrc 

# Install botocore
RUN echo "Installing botocore" && \
    pip3 install boto3 botocore

# Install aws-cli
RUN echo "Installing aws-cli" && \
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install -i /usr/local/aws-cli -b /usr/local/bin && \
    aws --version

# Install Session Manager Plugin
RUN echo "Installing Session Manager Plugin" && \
    curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "session-manager-plugin.deb" && \
    dpkg -i session-manager-plugin.deb && \
    rm session-manager-plugin.deb

# Install Terraform
RUN echo "Installing Terraform" && \
    wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor > /usr/share/keyrings/hashicorp-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list > /dev/null && \
    apt-get update && \
    apt-get install -y terraform && \
    rm -rf /var/lib/apt/lists/*

# Default command
CMD ["/bin/bash"]