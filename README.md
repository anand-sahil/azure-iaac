# Terraform Azure Modular Infrastructure + GitHub Actions CI/CD

Enterprise-grade Infrastructure-as-Code (IaC) project that provisions Azure resources using **Terraform** with a **modular architecture**, automated via **GitHub Actions** CI/CD pipelines across five environments: **Dev, Test, QA, UAT, and Prod**.

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Repository Structure](#repository-structure)
- [Prerequisites](#prerequisites)
- [Terraform Provider & Backend](#terraform-provider--backend)
- [Terraform Modules](#terraform-modules)
  - [1. Resource Group](#1-resource-group)
  - [2. Networking](#2-networking)
  - [3. Virtual Machines](#3-virtual-machines)
  - [4. Database](#4-database)
  - [5. Load Balancer](#5-load-balancer)
- [Root Module (infra/)](#root-module-infra)
- [Environments](#environments)
- [CI/CD Pipeline](#cicd-pipeline)
  - [Reusable Workflow](#reusable-workflow-terraform-multiyml)
  - [Environment Workflows](#environment-workflows)
  - [Pipeline Behavior Matrix](#pipeline-behavior-matrix)
  - [Workflow Dispatch Toggles](#workflow-dispatch-toggles)
- [ACA Runner Setup (Private + Managed Identity)](#aca-runner-setup-private--managed-identity)
  - [Step 1: Custom Runner Image](#step-1-custom-runner-image)
  - [Step 2: Azure Infrastructure](#step-2-azure-infrastructure)
  - [Step 3: Private Endpoints](#step-3-private-endpoints)
  - [Step 4: ACA Environment with VNet](#step-4-aca-environment-with-vnet)
  - [Step 5: ACA Job as GitHub Runner](#step-5-aca-job-as-github-runner)
  - [Step 6: GitHub Repository Variables](#step-6-github-repository-variables)
  - [Network Flow Diagram](#network-flow-diagram)
- [Authentication (Managed Identity)](#authentication-managed-identity)
- [Backend Configuration](#backend-configuration)
- [Getting Started](#getting-started)
- [Environment Protection & Approvals](#environment-protection--approvals)
- [GitHub Secrets Configuration](#github-secrets-configuration)
- [Infrastructure Per Environment](#infrastructure-per-environment)
- [Module Dependency Graph](#module-dependency-graph)
- [Security Best Practices](#security-best-practices)
- [Troubleshooting](#troubleshooting)
- [Author](#author)
- [License](#license)

---

## Architecture Overview

```
Developer → PR → terraform plan → Code Review → Merge → Push → terraform apply (with approval) → Azure
```

```
          ┌──────────────┐
          │ Pull Request │
          └──────┬───────┘
                 ▼
     Init → Fmt → Validate → Plan
                 │
            (No Apply)
                 ▼
        Reviewer Approves PR
                 ▼
          Merge to Main
                 ▼
          ┌───────────┐
          │   Push    │
          └─────┬─────┘
                ▼
  Init → Fmt → Validate → Plan → Apply (Approval Required)
```

**Key design principles:**

| Principle | Details |
|---|---|
| **Modular Terraform** | Each Azure resource type is an isolated, reusable module using `for_each` |
| **Multi-environment** | Separate `.tfvars` files for dev, test, qa, uat, and prod |
| **Managed Identity Auth** | Passwordless Azure auth via User-Assigned Managed Identity — zero secrets |
| **ACA Runners** | Event-driven Azure Container App Jobs as GitHub runners — scales to 0 |
| **Private Endpoints** | ACA runner and Storage Account communicate over private VNet — no public access |
| **GitOps Workflow** | Infrastructure changes flow through PRs; plan runs on PR, apply on merge |
| **Environment Protections** | Configurable approval gates per environment per stage |
| **Remote State** | Azure Storage backend with per-environment `.tfstate` files (Azure AD auth) |
| **Concurrency Control** | Per-environment concurrency groups prevent parallel pipeline runs |

---

## Repository Structure

```
azure-iaac-ga/
├── .github/
│   └── workflows/
│       ├── terraform-multi.yml       # Reusable workflow (init → plan → apply → destroy)
│       ├── dev.yaml                  # Dev environment pipeline
│       ├── test.yaml                 # Test environment pipeline
│       ├── uat.yaml                  # UAT environment pipeline
│       └── prod.yaml                # Production environment pipeline
├── environments/
│   ├── dev.tfvars                    # Dev variable values
│   ├── test.tfvars                   # Test variable values
│   ├── qa.tfvars                     # QA variable values
│   ├── uat.tfvars                    # UAT variable values
│   └── prod.tfvars                   # Production variable values
├── infra/
│   ├── main.tf                       # Root module — calls all child modules
│   ├── variables.tf                  # All input variable declarations
│   ├── output.tf                     # Root-level outputs
│   └── provider.tf                   # azurerm provider v4.41.0 + backend config
├── modules/
│   ├── resourceGroup/
│   │   └── azurerm_resource_group/   # Azure Resource Group
│   ├── networking/
│   │   ├── azurerm_virtual_network/  # VNet with dynamic subnets
│   │   ├── azurerm_nsg/              # Network Security Groups with dynamic rules
│   │   ├── azurerm_pip/              # Static Standard Public IPs
│   │   ├── azurerm_nic/              # NICs with dynamic IP configurations
│   │   ├── azurerm_nic_nsg_assoc/    # NIC ↔ NSG association
│   │   └── azurerm_bastion/          # Azure Bastion Host
│   ├── virtual_machine/              # Linux VMs with cloud-init support
│   ├── database/
│   │   ├── azurerm_mssql_server/     # Azure SQL Server
│   │   ├── azurerm_mssql_database/   # SQL Database
│   │   └── azurerm_mssql_firewall_rule/ # Conditional firewall rules
│   └── loadBalancer/
│       ├── azurerm_lb/               # Load Balancer with dynamic frontend IPs
│       ├── azurerm_backend_address_pool/ # Backend address pools
│       ├── azurerm_lb_probe/         # Health probes
│       ├── azurerm_lb_rule/          # Load balancing rules
│       └── azurerm_nic_bp_association/ # NIC ↔ Backend Pool association
├── runner/
│   └── Dockerfile                    # Custom GitHub Actions runner with Terraform + Azure CLI
├── LICENSE
└── README.md
```

---

## Prerequisites

| Requirement | Details |
|---|---|
| **Terraform** | >= 1.0 (project uses `azurerm` provider **v4.41.0**) |
| **Azure Subscription** | Active subscription with **Contributor** role |
| **User-Assigned Managed Identity** | For ACA runner auth to Azure (provider + state backend) |
| **Azure Storage Account** | For Terraform remote state backend (private endpoint, Azure AD auth) |
| **Azure Container Registry** | To host the custom runner image with Terraform pre-installed |
| **Azure Container App Job** | Event-driven runner (VNet-injected, with Managed Identity) |
| **GitHub PAT** | Personal Access Token with `repo` scope (for runner registration) |
| **GitHub Repository Variables** | `MI_CLIENT_ID`, `AZURE_SUBSCRIPTION_ID`, `AZURE_TENANT_ID` |

---

## Terraform Provider & Backend

```hcl
# provider.tf
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.41.0"
    }
  }
}

provider "azurerm" {
  features {}
  # Auth controlled via environment variables:
  #   ACA runner (MSI):  ARM_USE_MSI=true + ARM_CLIENT_ID
  #   Local dev:         az login (auto-detected)
}

terraform {
  backend "azurerm" {}
}
```

- **Provider:** `hashicorp/azurerm` v4.41.0
- **Authentication:** Managed Identity (`ARM_USE_MSI=true`) on ACA runner; `az login` locally
- **Backend:** Azure Storage with `use_azuread_auth=true` (Azure AD via MSI, no storage keys)
- **Private Endpoint:** Storage Account is accessed over private network from ACA's VNet

---

## Terraform Modules

### 1. Resource Group

**Path:** `modules/resourceGroup/azurerm_resource_group/`

Creates Azure Resource Groups using simple name + location inputs.

```hcl
resource "azurerm_resource_group" "resource_group_rb" {
  name     = var.rg_name
  location = var.location
}
```

| Variable | Type | Description |
|---|---|---|
| `rg_name` | `string` | Resource group name |
| `location` | `string` | Azure region (e.g., `North Europe`) |

| Output | Description |
|---|---|
| `rg_name1` | Created resource group name |
| `location1` | Created resource group location |
| `id1` | Resource group ID |

---

### 2. Networking

#### 2.1 Virtual Network (`azurerm_virtual_network`)

**Path:** `modules/networking/azurerm_virtual_network/`

Creates multiple VNets with **optional dynamic subnets** using `for_each`.

```hcl
resource "azurerm_virtual_network" "virtual_network_rb" {
  for_each      = var.vnets
  name          = each.value.vnet_name
  address_space = each.value.address_space
  # ... dynamic "subnet" block for optional subnets
}
```

| Variable | Type | Description |
|---|---|---|
| `vnets` | `map(object)` | VNet name, location, resource group, address space, optional subnets map |

| Output | Description |
|---|---|
| `virtual_networks` | Map of VNet key → name, location, subnet names |
| `vnet_subnet_ids` | Map of VNet name → subnet name → subnet ID |

---

#### 2.2 Network Security Group (`azurerm_nsg`)

**Path:** `modules/networking/azurerm_nsg/`

Creates NSGs with **dynamic security rules**. Rules are optional — an NSG can be created empty.

| Variable | Type | Description |
|---|---|---|
| `nsg` | `map(object)` | NSG name, location, resource group, optional security rules (name, priority, direction, access, protocol, port ranges, address prefixes) |

| Output | Description |
|---|---|
| `nsg_ids` | Map of NSG key → NSG ID |
| `nsg_names` | Map of NSG key → NSG name |

---

#### 2.3 Public IP (`azurerm_pip`)

**Path:** `modules/networking/azurerm_pip/`

Creates **Static Standard SKU** public IPs.

| Variable | Type | Description |
|---|---|---|
| `pips` | `map(object)` | PIP name, location, resource group |

| Output | Description |
|---|---|
| `pip_ids` | Map of PIP **name** → PIP ID (used by NIC module for association) |

---

#### 2.4 Network Interface (`azurerm_nic`)

**Path:** `modules/networking/azurerm_nic/`

Creates NICs with **dynamic IP configurations**. Supports:
- Static or Dynamic private IP allocation
- Optional public IP association (by name lookup)
- Multiple IP configurations per NIC with primary flag

| Variable | Type | Description |
|---|---|---|
| `nics` | `map(object)` | NIC name, resource group, VNet, subnet, IP configurations (allocation, optional static IP, optional PIP name, primary flag) |
| `pip_ids` | `map(string)` | Public IP name → ID map from the PIP module |

| Output | Description |
|---|---|
| `nic_ids` | Map of NIC key → NIC ID |
| `nic_names` | Map of NIC key → NIC name |
| `nic_private_ips` | Map of NIC key → first private IP |
| `nic_configs` | Map of NIC key → all IP configurations |
| `nic_ip_configs` | Map of NIC key → IP configuration details |

---

#### 2.5 NIC-NSG Association (`azurerm_nic_nsg_assoc`)

**Path:** `modules/networking/azurerm_nic_nsg_assoc/`

Associates existing NICs with existing NSGs using **data source lookups** (by name + resource group).

| Variable | Type | Description |
|---|---|---|
| `nic_nsg_ids` | `map(object)` | NIC name, NSG name, resource group for each association |

---

#### 2.6 Bastion Host (`azurerm_bastion`)

**Path:** `modules/networking/azurerm_bastion/`

Creates Azure Bastion hosts for secure, browser-based VM access. Requires:
- A dedicated `AzureBastionSubnet`
- A Standard public IP

| Variable | Type | Description |
|---|---|---|
| `bastion` | `map(object)` | Bastion name, location, resource group, VNet, subnet (`AzureBastionSubnet`), PIP name, IP configuration |

| Output | Description |
|---|---|
| `bastion_hosts` | Map of bastion key → name, ID, location |

---

### 3. Virtual Machines

**Path:** `modules/virtual_machine/`

Creates **Linux VMs** with configurable OS images, disk settings, and optional **cloud-init custom data** (base64-encoded). Password authentication is enabled (`disable_password_authentication = false`).

```hcl
resource "azurerm_linux_virtual_machine" "sahil-vm" {
  for_each = var.vms
  # Links to existing NIC via data source lookup
  # Supports custom_data for cloud-init scripts (e.g., Nginx + git deployments)
}
```

| Variable | Type | Description |
|---|---|---|
| `vms` | `map(object)` | VM name, resource group, location, size, admin credentials, NIC name, OS disk (caching, storage type), image reference (publisher, offer, sku, version), optional `custom_data` |

**Example custom_data usage (from tfvars):**
```bash
#!/bin/bash
sudo apt update -y
sudo apt install nginx git -y
sudo git clone <repo> /var/www/html/
sudo systemctl restart nginx
```

---

### 4. Database

#### 4.1 MSSQL Server (`azurerm_mssql_server`)

**Path:** `modules/database/azurerm_mssql_server/`

Creates Azure SQL Servers. Public network access is **disabled by default**.

| Variable | Type | Description |
|---|---|---|
| `sql_servers` | `map(object)` | Server name, resource group, location, version, admin login/password, optional `public_network_access_enabled` (default: `false`) |

| Output | Description |
|---|---|
| `sql_servers_ids` | Map of server key → server ID |

---

#### 4.2 MSSQL Database (`azurerm_mssql_database`)

**Path:** `modules/database/azurerm_mssql_database/`

Creates databases on existing SQL Servers. Uses a `locals` block to deduplicate server lookups when multiple databases share the same server.

| Variable | Type | Description |
|---|---|---|
| `sql_databases` | `map(object)` | Database name, server name reference, resource group, SKU (`Basic`, `S0`, etc.), optional collation (default: `SQL_Latin1_General_CP1_CI_AS`), max size GB (default: `5`), zone redundancy (default: `false`) |

| Output | Description |
|---|---|
| `sql_database_ids` | Map of database key → database ID |

---

#### 4.3 MSSQL Firewall Rule (`azurerm_mssql_firewall_rule`)

**Path:** `modules/database/azurerm_mssql_firewall_rule/`

Creates firewall rules **only** on SQL Servers with `public_network_access_enabled = true`. Uses conditional `for_each` with an `if` clause — servers with public access disabled are automatically skipped.

```hcl
for_each = {
  for rule_key, rule_val in var.firewall_rules :
  rule_key => rule_val
  if lookup(var.sql_servers, rule_val.server_id, ...).public_network_access_enabled == true
}
```

| Variable | Type | Description |
|---|---|---|
| `firewall_rules` | `map(object)` | Server reference key, rule name, start/end IP addresses |
| `sql_servers` | `map(object)` | Server configs (used for public access check) |
| `sql_servers_ids` | `map(string)` | Server key → server ID map |

---

### 5. Load Balancer

#### 5.1 Load Balancer (`azurerm_lb`)

**Path:** `modules/loadBalancer/azurerm_lb/`

Creates Azure Load Balancers with **dynamic frontend IP configurations** linked to existing public IPs.

| Variable | Type | Description |
|---|---|---|
| `azurerm_lb_rb` | `map(object)` | PIP name, resource group, LB name, location, SKU (`Standard`), frontend IP config list |

| Output | Description |
|---|---|
| `load_balancer_public_ips` | Map of LB key → LB name + public IP address |

---

#### 5.2 Backend Address Pool (`azurerm_backend_address_pool`)

**Path:** `modules/loadBalancer/azurerm_backend_address_pool/`

Creates backend address pools on existing load balancers (looked up by name).

| Variable | Type | Description |
|---|---|---|
| `backend_ap_rb` | `map(object)` | Resource group, LB name, backend pool name |

| Output | Description |
|---|---|
| `backend_address_pool_ids` | Map of pool key → pool ID |

---

#### 5.3 Health Probe (`azurerm_lb_probe`)

**Path:** `modules/loadBalancer/azurerm_lb_probe/`

Creates health probes with **5-second interval** and **2-probe threshold** (hardcoded).

| Variable | Type | Description |
|---|---|---|
| `lb_probe` | `map(object)` | Probe name, protocol (`Tcp`/`Http`), port, resource group, LB name |

| Output | Description |
|---|---|
| `lb_probes` | Map of probe key → name, ID, protocol, port |
| `lb_probe_ids` | Map of probe key → probe ID |

---

#### 5.4 Load Balancer Rule (`azurerm_lb_rule`)

**Path:** `modules/loadBalancer/azurerm_lb_rule/`

Creates load balancing rules mapping frontend ports → backend ports, associated with backend pools and health probes.

| Variable | Type | Description |
|---|---|---|
| `lb_rule` | `map(object)` | LB name, resource group, backend pool name, rule name, protocol, frontend/backend ports, frontend IP config name, probe name |
| `lb_probe_ids` | `map(string)` | Probe key → probe ID |

---

#### 5.5 NIC-Backend Pool Association (`azurerm_nic_bp_association`)

**Path:** `modules/loadBalancer/azurerm_nic_bp_association/`

Associates NICs with load balancer backend address pools (all via data source lookups).

| Variable | Type | Description |
|---|---|---|
| `nic_bp_association` | `map(object)` | NIC name + resource group, LB name + resource group, backend pool name, NIC IP config name |

| Output | Description |
|---|---|
| `nic_backend_associations` | Map of association key → NIC ID + backend pool ID |

---

## Root Module (infra/)

The root module (`infra/main.tf`) orchestrates all child modules using `for_each` and `depends_on`. Currently, only the **Resource Group module** is active — all other modules are commented out but fully wired:

```hcl
# Active
module "rg_module"              # Resource Groups (for_each)

# Available (commented out, ready to enable)
module "vnet_module"            # Virtual Networks
module "nsg_module"             # Network Security Groups
module "pip_module"             # Public IPs
module "nic_module"             # Network Interfaces
module "bastion_module"         # Bastion Host
module "nic_nsg_assoc_module"   # NIC-NSG Associations
module "vm_module"              # Linux VMs
module "sql_server"             # SQL Servers
module "firewall_rule"          # SQL Firewall Rules
module "database"               # SQL Databases
module "loadbalancer"           # Load Balancers
module "backendaddresspool"     # Backend Address Pools
module "nic_bp_association"     # NIC-Backend Pool Associations
module "lb_health_probe"        # Health Probes
module "lb_rule"                # LB Rules
```

**Root outputs** (active): `resource_group_ob_names`, `resource_group_ob_locations`, `resource_group_ob_ids`

---

## Environments

Each environment has its own `.tfvars` file in `environments/` with environment-specific naming suffixes.

| Environment | File | Naming Pattern | Resource Group | State File |
|---|---|---|---|---|
| **Dev** | `dev.tfvars` | base names | `sahil-hrutviatri` | `dev.tfstate` |
| **Test** | `test.tfvars` | `*-test` | `sahil-test-rg1` | `test.tfstate` |
| **QA** | `qa.tfvars` | `*-qa` | `sahil-qa-rg1` | `qa.tfstate` |
| **UAT** | `uat.tfvars` | `*-uat` | `sahil-uat-rg1` | `uat.tfstate` |
| **Prod** | `prod.tfvars` | `*-prod` | `sahil-prod-rg1` | `prod.tfstate` |

All environments share the same region (**North Europe**) and identical infrastructure topology. Differences are only in resource names and state isolation.

---

## CI/CD Pipeline

### Reusable Workflow (`terraform-multi.yml`)

All environment pipelines call a single reusable workflow that executes these jobs **sequentially**:

```
preview-options → init → plan → apply → destroy
```

| Job | Steps | Condition |
|---|---|---|
| **preview-options** | Logs trigger event and all input values | Always |
| **init** | Checkout → `terraform init` (with backend config + `use_azuread_auth`) → `terraform fmt -recursive` → `terraform validate` | `runInit = true` |
| **plan** | Checkout → Init → `terraform plan -var-file` → Upload plan artifact | `runPlan = true` & init succeeded |
| **apply** | Download plan artifact → Init → `terraform apply -auto-approve <plan-file>` | `runApply = true` & plan succeeded |
| **destroy** | Checkout → Init → `terraform destroy -auto-approve -var-file` | `runDestroy = true` (manual only) |

Each job supports optional **environment protection** for approval gates via `useEnvironment*` toggles.

All jobs run on **ACA runners** (`runs-on: aca-runner`) with Managed Identity authentication. Environment variables `ARM_USE_MSI`, `ARM_CLIENT_ID`, `ARM_SUBSCRIPTION_ID`, and `ARM_TENANT_ID` are set globally in the workflow — no `azure/login` step needed.

---

### Environment Workflows

Each environment has a dedicated workflow YAML (e.g., `dev.yaml`, `prod.yaml`) that:

1. **Triggers** on `push` to `main` when the corresponding `environments/<env>.tfvars` is modified
2. **Triggers** on manual `workflow_dispatch` with stage and approval toggles
3. **Calls** `terraform-multi.yml` with environment-specific parameters (tfvars file, backend key, etc.)

**Concurrency:** Each environment uses a dedicated concurrency group (e.g., `dev-tf`, `prod-tf`) to prevent parallel runs.

---

### Pipeline Behavior Matrix

| Environment | Auto Init on Push | Auto Plan on Push | Auto Apply on Push | Apply Approval on Push | Destroy |
|---|---|---|---|---|---|
| **Dev** | No | No | No | N/A | Manual only |
| **Test** | No | No | No | N/A | Manual only |
| **UAT** | No | No | No | N/A | Manual only |
| **QA** | No | No | No | N/A | Manual only |
| **Prod** | **Yes** | **Yes** | **Yes** | **Required** | Manual only |

> **Production is the only environment that auto-applies on push.** All other environments require manual `workflow_dispatch` with explicit `do_apply = true`.

---

### Workflow Dispatch Toggles

All environment workflows support manual triggering with these inputs:

| Input | Type | Description |
|---|---|---|
| `do_init` | `boolean` | Run `terraform init` + `fmt` + `validate` |
| `do_plan` | `boolean` | Run `terraform plan` |
| `do_apply` | `boolean` | Run `terraform apply` |
| `do_destroy` | `boolean` | Run `terraform destroy` |
| `use_environment_init` | `boolean` | Require environment approval for init |
| `use_environment_plan` | `boolean` | Require environment approval for plan |
| `use_environment_apply` | `boolean` | Require environment approval for apply |
| `use_environment_destroy` | `boolean` | Require environment approval for destroy |

---

## ACA Runner Setup (Private + Managed Identity)

This project runs GitHub Actions on **Azure Container App (ACA) Jobs** — event-driven, scales to 0, VNet-injected, authenticated via **User-Assigned Managed Identity**. The runner image includes Terraform and Azure CLI. Both the ACA environment and the state storage account use **private endpoints** (no public internet access).

### Step 1: Custom Runner Image

A custom Dockerfile (`runner/Dockerfile`) extends the official GitHub Actions runner with Terraform and Azure CLI:

```dockerfile
FROM ghcr.io/actions/actions-runner:latest

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl unzip gnupg software-properties-common ca-certificates \
    apt-transport-https lsb-release git jq \
    && rm -rf /var/lib/apt/lists/*

# Install Terraform
ARG TERRAFORM_VERSION=1.12.0
RUN curl -fsSL "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip" -o terraform.zip \
    && unzip terraform.zip -d /usr/local/bin/ && rm terraform.zip

# Install Azure CLI
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash

USER runner
```

**Build and push to Azure Container Registry:**

```bash
# Variables
ACR_NAME="acatfimage"
RUNNER_RG="rg-github-runners"
LOCATION="northeurope"

#Create RG (if not exists)
az group create --name rg-github-runners --location northeurope

# Create ACR (if not exists)
az acr create --name $ACR_NAME --resource-group $RUNNER_RG --location $LOCATION --sku Premium --admin-enabled false

# Build and push
az acr build --registry $ACR_NAME --image github-runner-terraform:latest --file runner/Dockerfile runner/
```

---

### Step 2: Azure Infrastructure

```bash
# ──────────────────────────────────────
# Variables — UPDATE THESE
# ──────────────────────────────────────
SUBSCRIPTION_ID="<your-subscription-id>"
LOCATION="northeurope"
RUNNER_RG="rg-github-runners"
MI_NAME="mi-github-runner"
ACR_NAME="<your-acr-name>"

# Existing state storage
STATE_RG="sahilkasav"
STATE_SA="sahilkascv"

# GitHub
GITHUB_ORG="<your-github-org-or-username>"
GITHUB_REPO="<your-repo-name>"
GITHUB_PAT="<your-github-pat>"   # needs repo scope

az account set --subscription $SUBSCRIPTION_ID

# 1. Create resource group for runner infra
az group create --name $RUNNER_RG --location $LOCATION

# 2. Create User-Assigned Managed Identity
az identity create --name $MI_NAME --resource-group $RUNNER_RG --location $LOCATION

MI_CLIENT_ID=$(az identity show --name $MI_NAME --resource-group $RUNNER_RG --query clientId -o tsv)
MI_PRINCIPAL_ID=$(az identity show --name $MI_NAME --resource-group $RUNNER_RG --query principalId -o tsv)
MI_RESOURCE_ID=$(az identity show --name $MI_NAME --resource-group $RUNNER_RG --query id -o tsv)

# 3. Assign RBAC roles to the Managed Identity

# Contributor on subscription (Terraform needs this to manage resources)
az role assignment create \
  --assignee $MI_PRINCIPAL_ID \
  --role "Contributor" \
  --scope "/subscriptions/$SUBSCRIPTION_ID"

# Storage Blob Data Contributor on state storage (Terraform backend via Azure AD)
STATE_SA_ID=$(az storage account show --name $STATE_SA --resource-group $STATE_RG --query id -o tsv)
az role assignment create \
  --assignee $MI_PRINCIPAL_ID \
  --role "Storage Blob Data Contributor" \
  --scope "$STATE_SA_ID"

# AcrPull on ACR (so ACA can pull the runner image)
ACR_ID=$(az acr show --name $ACR_NAME --query id -o tsv)
az role assignment create \
  --assignee $MI_PRINCIPAL_ID \
  --role "AcrPull" \
  --scope "$ACR_ID"
```

---

### Step 3: Private Endpoints

#### 3a. Create VNet for ACA runners

```bash
ACA_VNET="vnet-aca-runners"
ACA_INFRA_SUBNET="snet-aca-infra"        # Delegated to ACA environment
ACA_PE_SUBNET="snet-private-endpoints"    # For storage + ACR private endpoints

# Create VNet with two subnets
az network vnet create \
  --name $ACA_VNET \
  --resource-group $RUNNER_RG \
  --location $LOCATION \
  --address-prefix "10.100.0.0/16"

# ACA infrastructure subnet (minimum /23, delegated to Microsoft.App/environments)
az network vnet subnet create \
  --name $ACA_INFRA_SUBNET \
  --vnet-name $ACA_VNET \
  --resource-group $RUNNER_RG \
  --address-prefix "10.100.0.0/23" \
  --delegations "Microsoft.App/environments"

# Private endpoint subnet (no delegations needed)
az network vnet subnet create \
  --name $ACA_PE_SUBNET \
  --vnet-name $ACA_VNET \
  --resource-group $RUNNER_RG \
  --address-prefix "10.100.2.0/24"
```

#### 3b. Create Private DNS Zones

```bash
# Private DNS zone for Storage blob
az network private-dns zone create \
  --resource-group $RUNNER_RG \
  --name "privatelink.blob.core.windows.net"

# Link DNS zone to VNet
az network private-dns link vnet create \
  --resource-group $RUNNER_RG \
  --zone-name "privatelink.blob.core.windows.net" \
  --name "link-aca-vnet-blob" \
  --virtual-network $ACA_VNET \
  --registration-enabled false

# Private DNS zone for ACR
az network private-dns zone create \
  --resource-group $RUNNER_RG \
  --name "privatelink.azurecr.io"

az network private-dns link vnet create \
  --resource-group $RUNNER_RG \
  --zone-name "privatelink.azurecr.io" \
  --name "link-aca-vnet-acr" \
  --virtual-network $ACA_VNET \
  --registration-enabled false
```

#### 3c. Create Private Endpoint for Storage Account

```bash
# Disable public access on state storage
az storage account update \
  --name $STATE_SA \
  --resource-group $STATE_RG \
  --public-network-access Disabled

# Create private endpoint for blob
PE_SUBNET_ID=$(az network vnet subnet show --name $ACA_PE_SUBNET --vnet-name $ACA_VNET --resource-group $RUNNER_RG --query id -o tsv)

az network private-endpoint create \
  --name "pe-state-storage" \
  --resource-group $RUNNER_RG \
  --vnet-name $ACA_VNET \
  --subnet $ACA_PE_SUBNET \
  --private-connection-resource-id "$STATE_SA_ID" \
  --group-id "blob" \
  --connection-name "pec-state-blob"

# Create DNS zone group (auto-registers A record in private DNS)
az network private-endpoint dns-zone-group create \
  --resource-group $RUNNER_RG \
  --endpoint-name "pe-state-storage" \
  --name "default" \
  --private-dns-zone "privatelink.blob.core.windows.net" \
  --zone-name "blob"
```

#### 3d. Create Private Endpoint for ACR

```bash
# Disable public access on ACR
az acr update --name $ACR_NAME --public-network-enabled false

# Create private endpoint for ACR
az network private-endpoint create \
  --name "pe-acr" \
  --resource-group $RUNNER_RG \
  --vnet-name $ACA_VNET \
  --subnet $ACA_PE_SUBNET \
  --private-connection-resource-id "$ACR_ID" \
  --group-id "registry" \
  --connection-name "pec-acr-registry"

az network private-endpoint dns-zone-group create \
  --resource-group $RUNNER_RG \
  --endpoint-name "pe-acr" \
  --name "default" \
  --private-dns-zone "privatelink.azurecr.io" \
  --zone-name "registry"
```

---

### Step 4: ACA Environment with VNet

```bash
ACA_ENV_NAME="aca-env-runners"
ACA_INFRA_SUBNET_ID=$(az network vnet subnet show --name $ACA_INFRA_SUBNET --vnet-name $ACA_VNET --resource-group $RUNNER_RG --query id -o tsv)

# Create ACA environment injected into VNet
az containerapp env create \
  --name $ACA_ENV_NAME \
  --resource-group $RUNNER_RG \
  --location $LOCATION \
  --infrastructure-subnet-resource-id $ACA_INFRA_SUBNET_ID \
  --internal-only true
```

> `--internal-only true` means the ACA environment has **no public ingress** — all traffic stays on the VNet. The runner communicates to Storage and ACR via private endpoints.

---

### Step 5: ACA Job as GitHub Runner

```bash
ACA_JOB_NAME="aca-github-runner"
ACR_LOGIN_SERVER=$(az acr show --name $ACR_NAME --query loginServer -o tsv)

### we can use azure keyvault instead for secrets

az containerapp job create \
  --name "$ACA_JOB_NAME" \
  --resource-group "$RUNNER_RG" \
  --environment "$ACA_ENV_NAME" \
  --trigger-type "Event" \
  --replica-timeout 1800 \
  --replica-retry-limit 0 \
  --replica-completion-count 1 \
  --parallelism 1 \
  --min-executions 0 \
  --max-executions 10 \
  --polling-interval 30 \
  --image "${ACR_LOGIN_SERVER}/github-runner-terraform:latest" \
  --registry-server "$ACR_LOGIN_SERVER" \
  --registry-identity "$MI_RESOURCE_ID" \
  --cpu "2.0" \
  --memory "4Gi" \
  --secrets "github-pat=$GITHUB_PAT" \
 --env-vars "GITHUB_PAT=secretref:github-pat" "GH_URL=https://github.com/$GITHUB_ORG/$GITHUB_REPO" "REGISTRATION_TOKEN_API_URL=https://api.github.com/repos/$GITHUB_ORG/$GITHUB_REPO/actions/runners/registration-token" "LABELS=aca-runner" \
  --mi-user-assigned "$MI_RESOURCE_ID" \
  --scale-rule-name "github-runner-rule" \
  --scale-rule-type "github-runner" \
  --scale-rule-metadata \
    "githubAPIURL=https://api.github.com" \
    "owner=$GITHUB_ORG" \
    "repo=$GITHUB_REPO" \
    "runnerScope=repo" \
  --scale-rule-auth "personalAccessToken=github-pat"
```

**Key flags:**
- `--registry-identity` — pulls image from ACR using Managed Identity (no admin credentials)
- `--mi-user-assigned` — attaches MI so the runner container can authenticate to Azure
- `--image` — uses your custom image with Terraform + Azure CLI pre-installed
- `LABELS=aca-runner` — must match `runs-on: aca-runner` in workflow YAML

---

### Step 6: GitHub Repository Variables

Store non-sensitive identifiers as **repository variables** (not secrets):

```bash
gh variable set MI_CLIENT_ID --body "$MI_CLIENT_ID" --repo "$GITHUB_ORG/$GITHUB_REPO"
gh variable set AZURE_SUBSCRIPTION_ID --body "$SUBSCRIPTION_ID" --repo "$GITHUB_ORG/$GITHUB_REPO"
gh variable set AZURE_TENANT_ID --body "$(az account show --query tenantId -o tsv)" --repo "$GITHUB_ORG/$GITHUB_REPO"
```

Or manually: **Repository → Settings → Secrets and variables → Actions → Variables tab → New repository variable**

| Variable | Value | Description |
|---|---|---|
| `MI_CLIENT_ID` | Managed Identity client ID | Used as `ARM_CLIENT_ID` in workflow |
| `AZURE_SUBSCRIPTION_ID` | Subscription ID | Used as `ARM_SUBSCRIPTION_ID` |
| `AZURE_TENANT_ID` | Tenant ID | Used as `ARM_TENANT_ID` |

---

### Network Flow Diagram

```
GitHub.com
    │ (webhook: workflow queued)
    ▼
KEDA Scaler (polls GitHub API over internet)
    │
    ▼
ACA Job scales up inside VNet (snet-aca-infra 10.100.0.0/23)
    │
    ├──── Private Endpoint ──── Azure Storage (state file)
    │     (snet-private-endpoints   privatelink.blob.core.windows.net)
    │     10.100.2.0/24)            No public access
    │
    ├──── Private Endpoint ──── Azure Container Registry (runner image pull)
    │                               privatelink.azurecr.io
    │                               No public access
    │
    ├──── ARM_USE_MSI=true ──── Azure Resource Manager API
    │     (Managed Identity)        (manages infra: RGs, VNets, VMs, SQL, LBs)
    │
    └──── Job completes → container terminates → scales to 0 ($0 cost)
```

**What stays private:**
- State file read/write (Storage blob via private endpoint)
- Runner image pull (ACR via private endpoint)

**What goes over internet:**
- GitHub webhook / KEDA polling (GitHub API)
- Azure Resource Manager API calls (ARM endpoints)

---

## Authentication (Managed Identity)

The ACA runner container has a **User-Assigned Managed Identity** attached. Terraform uses it for both **provider auth** (managing Azure resources) and **backend auth** (reading/writing state files).

**Environment variables set globally in `terraform-multi.yml`:**

```yaml
env:
  ARM_USE_MSI: "true"
  ARM_CLIENT_ID: ${{ vars.MI_CLIENT_ID }}
  ARM_SUBSCRIPTION_ID: ${{ vars.AZURE_SUBSCRIPTION_ID }}
  ARM_TENANT_ID: ${{ vars.AZURE_TENANT_ID }}
```

**Backend auth via `terraform init`:**

```bash
terraform init \
  -backend-config="use_azuread_auth=true" \
  -backend-config="resource_group_name=..." \
  -backend-config="storage_account_name=..." \
  -backend-config="container_name=..." \
  -backend-config="key=dev.tfstate"
```

| Component | Auth Method | Details |
|---|---|---|
| **azurerm provider** | `ARM_USE_MSI=true` | MSI token auto-acquired from IMDS inside ACA container |
| **azurerm backend** | `use_azuread_auth=true` | State blob accessed via Azure AD (MSI), not storage keys |
| **ACR image pull** | `--registry-identity` | ACA pulls runner image from ACR using the same MSI |

> **No secrets, no OIDC federation, no App Registration.** The Managed Identity on the ACA container handles everything.

---

## Backend Configuration

Terraform state is stored remotely in **Azure Blob Storage** with per-environment state files for full isolation. Access is via **Azure AD auth** (Managed Identity) over a **private endpoint** — no storage account keys are used, and no public network access is enabled.

Backend parameters are passed at `terraform init` via the CI/CD pipeline:

| Parameter | Value | Notes |
|---|---|---|
| `resource_group_name` | e.g., `sahilkasav` | Resource group containing the storage account |
| `storage_account_name` | e.g., `sahilkascv` | Storage account for state files |
| `container_name` | e.g., `sahilkascv` | Blob container name |
| `key` | `dev.tfstate` / `prod.tfstate` | Per-environment state file |
| `use_azuread_auth` | `true` | Authenticate to storage via Azure AD (MSI), not access keys |

```bash
terraform init \
  -backend-config="resource_group_name=sahilkasav" \
  -backend-config="storage_account_name=sahilkascv" \
  -backend-config="container_name=sahilkascv" \
  -backend-config="key=dev.tfstate" \
  -backend-config="use_azuread_auth=true"
```

---

## Getting Started

### Local Development

```bash
# 1. Clone
git clone <repository-url>
cd azure-iaac-ga

# 2. Authenticate to Azure
az login

# 3. Initialize Terraform with backend
cd infra
terraform init \
  -backend-config="resource_group_name=<rg-name>" \
  -backend-config="storage_account_name=<sa-name>" \
  -backend-config="container_name=<container-name>" \
  -backend-config="key=dev.tfstate" \
  -backend-config="use_azuread_auth=true"

# 4. Validate
terraform validate

# 5. Plan
terraform plan -var-file="../environments/dev.tfvars"

# 6. Apply
terraform apply -var-file="../environments/dev.tfvars"
```

### CI/CD Deployment

1. Modify `environments/<env>.tfvars` with desired changes
2. Create a **Pull Request** to `main` → pipeline runs `plan` for review
3. After PR approval and merge:
   - **Prod:** Automatically runs init → plan → apply (with environment approval gate)
   - **Other environments:** Trigger manually via **Actions → workflow_dispatch** with desired toggles

---

## Environment Protection & Approvals

GitHub Environments enforce manual approvals for critical stages like `apply` and `destroy`.

### Setup Steps

1. **Add Collaborators/Teams**
   - Repository → Settings → Collaborators & Teams
   - Recommended: create a GitHub Team (e.g., `infra-approvers`)

2. **Create Environments**
   - Settings → Environments → New Environment
   - Create: `dev`, `qa`, `test`, `uat`, `prod`

3. **Configure Protection Rules**
   - Click environment → Required reviewers → select approvers
   - Optionally configure: wait timer, deployment branch policies, minimum reviewers

4. **Add Environment Secrets (optional)**
   - Per-environment Azure credentials if using separate subscriptions

5. **Link Workflows**
   - Jobs reference environments via the `environment:` key
   - When a job references a protected environment, GitHub pauses and sends an approval request

---

## GitHub Secrets Configuration

### Required Repository Variables (not secrets)

With Managed Identity, Azure credentials are **non-sensitive** identifiers stored as **GitHub repository variables**:

| Variable Name | Description |
|---|---|
| `MI_CLIENT_ID` | User-Assigned Managed Identity client ID |
| `AZURE_SUBSCRIPTION_ID` | Target Azure subscription ID |
| `AZURE_TENANT_ID` | Azure AD tenant ID |

### How to Add

1. Repository → Settings → Secrets and variables → Actions → **Variables** tab
2. Click **New repository variable**
3. Add each variable

### Only Secret Remaining

| Secret Name | Description |
|---|---|
| GitHub PAT (in ACA Job) | Stored as an ACA container secret for runner registration — never in GitHub Secrets |

### Best Practices

- Use **repository variables** (not secrets) for non-sensitive Azure identifiers
- The GitHub PAT is stored only in ACA Job secrets — not exposed in workflow YAML
- Restrict variable editing to trusted admins
- Test workflows in non-production environments before deploying to prod
- Run `terraform plan` before `terraform apply` to validate credentials and changes

---

## Infrastructure Per Environment

Each environment (when all modules are enabled) provisions:

| Resource | Count | Details |
|---|---|---|
| Resource Group | 1 | Region: North Europe |
| Virtual Network | 1 | `10.0.0.0/23` with 4 subnets |
| Subnets | 4 | `subnet1`, `subnet2`, `subnet3`, `AzureBastionSubnet` |
| NSG | 1 | Allows inbound HTTP (port 80) |
| Public IPs | 4 | For NICs, Bastion, and Load Balancer |
| NICs | 2 | Frontend (dynamic IP + PIP) and Backend (static IP) |
| NIC-NSG Associations | 2 | Both NICs linked to NSG |
| Bastion Host | 1 | Secure browser-based VM access |
| Linux VMs | 2 | Frontend + Backend (Nginx with git-based app deploy via cloud-init) |
| SQL Server | 1 | Admin credentials, public access configurable |
| SQL Databases | 2 | `appdb` (Basic SKU) and `analyticsdb` (S0 SKU) |
| SQL Firewall Rules | 2 | IP-based access control (conditional on public access flag) |
| Load Balancer | 1 | Standard SKU with public frontend IP |
| Backend Pool | 1 | Associated with NIC |
| Health Probe | 1 | TCP on port 80, 5s interval, 2-probe threshold |
| LB Rule | 1 | Port 80 → Port 80 (TCP) |

---

## Module Dependency Graph

Module dependencies enforced via `depends_on` in `infra/main.tf`:

```
Resource Group
├── Virtual Network
├── NSG
├── Public IP
├── Bastion Host ← VNet, PIP
├── NIC ← VNet, NSG, PIP
│   └── NIC-NSG Association ← NIC, NSG
│       └── NIC-Backend Pool Association ← NIC, Backend Pool
├── Virtual Machine ← NIC
├── SQL Server
│   ├── Firewall Rules ← SQL Server
│   └── SQL Database ← SQL Server, Firewall Rules
└── Load Balancer ← PIP
    ├── Backend Address Pool ← LB
    ├── Health Probe ← NIC-BP Association
    └── LB Rule ← Health Probe, NIC-BP Association
```

---

## Security Best Practices

- **Managed Identity** — no client secrets, no OIDC federation, no App Registration needed
- **Private endpoints** — Storage and ACR accessed over VNet (no public network access)
- **ACA internal-only** — runner environment has no public ingress
- **Azure AD auth for state** — `use_azuread_auth=true` (no storage access keys)
- **Remote state** in Azure Storage — never committed to the repository
- **`.gitignore`** excludes `*.tfstate`, `terraform.tfvars`, `.terraform/`
- **GitHub repository variables** (not secrets) for non-sensitive Azure IDs
- **Branch protection** — PRs required, direct push to `main` blocked
- **Approval gates** — apply and destroy require reviewer sign-off (especially prod)
- **Concurrency groups** — prevent parallel pipeline runs per environment
- **SQL Server public access** disabled by default; firewall rules conditionally created
- **Least privilege** — Contributor role on subscription, Storage Blob Data Contributor on state SA, AcrPull on ACR
- Enable **soft delete** and **versioning** on the state storage account
- State file **blob immutability** (optional) for compliance
- **Scale to zero** — ACA runners cost $0 when idle

---

## Troubleshooting

| Problem | Solution |
|---|---|
| **Apply not running?** | Check: environment approval pending, reviewer permissions, branch protection rules |
| **Unauthorized for Azure?** | Verify: MI has Contributor role, `ARM_USE_MSI=true` is set, MI is attached to ACA Job |
| **State access denied?** | Check: MI has `Storage Blob Data Contributor` on storage account, `use_azuread_auth=true` in init, private endpoint + DNS resolving correctly |
| **ACR image pull fails?** | Check: MI has `AcrPull` on ACR, private endpoint for ACR exists, DNS zone linked to VNet |
| **Destroy not running?** | Destroy only runs via `workflow_dispatch` with `do_destroy = true` |
| **State lock conflict?** | Another pipeline may be running — check concurrency group or force-unlock the state |
| **Module not deploying?** | Uncomment the module block in `infra/main.tf` and its corresponding outputs in `output.tf` |
| **Plan succeeds but apply fails?** | Check Azure RBAC permissions, resource quotas, and naming conflicts |
| **Runner not picking up jobs?** | Verify: ACA Job label matches `runs-on`, KEDA scaler configured, PAT has `repo` scope |

---

## Author

**[Sahil Sharma](https://www.linkedin.com/in/hrutviatri/)**
DevOps Engineer | Azure | Terraform | CI/CD | Docker | Kubernetes

[![LinkedIn](https://img.shields.io/badge/LinkedIn-0A66C2?style=for-the-badge&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/hrutviatri/)
[![GitHub](https://img.shields.io/badge/GitHub-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/hrutviatri)

---

## License

This project is licensed under the **MIT License**. See [LICENSE](LICENSE) for details.
