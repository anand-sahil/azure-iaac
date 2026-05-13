FROM ghcr.io/actions/actions-runner:latest

USER root

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    unzip \
    gnupg \
    software-properties-common \
    ca-certificates \
    apt-transport-https \
    lsb-release \
    git \
    jq \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Install Terraform
ARG TERRAFORM_VERSION=1.12.0
RUN curl -fsSL "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" -o terraform.zip \
    && unzip terraform.zip -d /usr/local/bin/ \
    && rm terraform.zip \
    && terraform version

# Install Azure CLI
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash \
    && az version

# Allow runner user to use sudo (needed for some Terraform providers)
RUN echo "runner ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/runner

COPY entrypoint.sh /home/runner/entrypoint.sh
RUN sed -i 's/\r$//' /home/runner/entrypoint.sh && chmod +x /home/runner/entrypoint.sh

USER runner
WORKDIR /home/runner

ENTRYPOINT ["/home/runner/entrypoint.sh"]
