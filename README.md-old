# 🏗️ Terraform Azure Modular Infrastructure + GitHub Actions CI/CD  
## **(Ultra-Advanced, Fully Updated, A-to-Z Complete DevOps Documentation)**  
### **Everything you need to understand — Setup → Infrastructure → CI/CD → Approvals → PR Flow → Security → Azure OIDC → Environments → Backend → Modules → Execution → Best Practices → Governance**

This README is designed so even a new DevOps engineer can understand:
👉 Terraform  
👉 Azure  
👉 GitHub Actions  
👉 OIDC  
👉 Multi-Environment Pipelines  
👉 Production Safety  
👉 Dynamic Approvals  
👉 PR-Only Change Flow  
👉 Self-Hosted Runners  
👉 Secure State Backends  
👉 Environments & Protected Branches

---

# ⭐ 1. PROJECT GOAL — WHAT THIS REPO PROVIDES

This project showcases **enterprise-grade DevOps automation** using **Terraform + Azure + GitHub Actions** with:

- Modular Terraform structure  
- Multi-environment CI/CD  
- Secure OIDC authentication  
- Branch protection (PR mandatory)  
- Plan-only on PRs  
- Apply with approval on push  
- Full manual control through workflow_dispatch  
- Self-hosted runners for better performance  
- Remote backend with Azure Storage  
- Federated credentials (no secrets)  
- Environment protections (Prod/UAT/QA/Test)  

In short:

✔ **Fully automated Infrastructure-as-Code pipeline**  
✔ **Zero secrets authentication**  
✔ **Enterprise safety with approvals & protected branches**  
✔ **GitOps-style workflow**  

---

# 🧭 2. HIGH-LEVEL ARCHITECTURE — EVERYTHING AT A GLANCE

```
Developer → PR → Plan → Review → Merge → Push → Apply (Approval) → Azure Infra
```

---

# 🏛️ 3. TERRAFORM ARCHITECTURE (MODULAR)

This repository follows a clean, scalable, modular approach:

```
infra/
│
├── main.tf
├── provider.tf
├── variables.tf
├── terraform.tfvars
├── outputs.tf
│
└── modules/
    ├── resourceGroup/
    ├── networking/
    │   ├── vnet
    │   ├── subnet
    │   ├── nsg
    │   └── public-ip
    ├── virtual_machine/
    ├── database/
    └── loadBalancer/
```

### Key Advantages:
- Reusable modules  
- Clean separation  
- Easy to scale  
- Easy to maintain  
- Supports multi-environment deployment  

---

# 🔒 4. REMOTE BACKEND (AZURE STORAGE)

Terraform state is stored safely in Azure Storage:

- Storage Account  
- Container  
- State file for each environment:
  - dev.tfstate  
  - qa.tfstate  
  - test.tfstate  
  - uat.tfstate  
  - prod.tfstate  

---

# 🔐 5. SECURE OIDC — ZERO SECRETS

Instead of storing Client Secret in GitHub, you use **OpenID Connect**:

- More secure  
- No secrets leakage  
- Azure trusts GitHub identity tokens  
- Federated credentials bind repo → branch/environment  

OIDC Setup Includes:
1. Azure App Registration  
2. Role assignment  
3. Federated Credential  
4. GitHub Actions Login  

---

# 🔰 6. ENVIRONMENTS & APPROVALS (Prod, UAT, QA, Test)

Every environment has:
- Protected deployment  
- Required reviewers  
- Optional environment secrets  
- Approval gating  

Especially **prod**, where Apply ALWAYS requires approval (on push).

---

# 🚫 7. BRANCH PROTECTION — PR ONLY WORKFLOW

**Direct push to main is blocked**  
Developers MUST create a pull request.

This ensures:
- Code review  
- Terraform plan validation  
- No accidental deployments  

Branch protection settings:
- Require PR  
- Require plan job to pass  
- Require review  
- Block direct pushes  

---

# 🔁 8. FULL CICD FLOW (A → Z)

## 🔵 A. Pull Request (Safe Mode)
Runs:
- Init  
- Fmt  
- Validate  
- Plan  

❌ No Apply  
❌ No Destroy  

Used for:
- Reviewing Terraform changes  
- Validating infrastructure impact  

---

## 🟢 B. After PR Approval → Merge → Push

This triggers full pipeline:

```
Init → Fmt → Validate → Plan → Apply
```

BUT:
- Apply ALWAYS requires approval  
- Approval based on environment protection  

This ensures:
- Code review before merge  
- Change impact known before merge  
- Approval before actual infra modification  

---

## 🟠 C. workflow_dispatch (Manual Control)

You can run:
- Init  
- Plan  
- Apply  
- Destroy  

With:
- Optional approvals  
- Optional stages  

Example:
- Only Plan in prod  
- Apply with approval in QA  
- Destroy in Test with approval  

---

# 🧠 9. DYNAMIC APPROVAL TOGGLES (NEW FEATURE)

Each environment job supports:

| Stage | Run Flag | Approval Flag |
|-------|----------|----------------|
| Init | `do_init` | `use_environment_init` |
| Plan | `do_plan` | `use_environment_plan` |
| Apply | `do_apply` | `use_environment_apply` |
| Destroy | `do_destroy` | `use_environment_destroy` |

This provides COMPLETE CONTROL.

---

# 🧩 10. PROD WORKFLOW (FULL FINAL VERSION)

```yaml
name: prod

on:
  push:
    branches:
      - main
    paths:
      - 'environments/prod.tfvars'

  pull_request:
    branches:
      - main
    paths:
      - 'environments/prod.tfvars'

  workflow_dispatch:
    inputs:
      use_environment_init:    { type: boolean, default: false }
      do_init:                 { type: boolean, default: false }

      use_environment_plan:    { type: boolean, default: false }
      do_plan:                 { type: boolean, default: false }

      use_environment_apply:   { type: boolean, default: false }
      do_apply:                { type: boolean, default: false }

      use_environment_destroy: { type: boolean, default: false }
      do_destroy:              { type: boolean, default: false }

permissions:
  contents: read
  id-token: write

concurrency:
  group: prod-tf
  cancel-in-progress: false

jobs:
  call:
    uses: ./.github/workflows/terraform-multi.yml
    with:
      environment:  prod
      tfvars_file:  environments/prod.tfvars
      rgname:       ritkargv
      saname:       ritkasav
      scname:       ritkascv
      key:          prod.tfstate

      runInit:     ${{ github.event_name != 'pull_request' && (github.event_name == 'push' || inputs.do_init == true) }}
      runPlan:     ${{ github.event_name == 'pull_request' || github.event_name == 'push' || inputs.do_plan == true }}
      runApply:    ${{ github.event_name == 'push' || inputs.do_apply == true }}
      runDestroy:  ${{ github.event_name == 'workflow_dispatch' && inputs.do_destroy == true }}

      useEnvironmentInit:    ${{ github.event_name == 'workflow_dispatch' && inputs.use_environment_init == true }}
      useEnvironmentPlan:    ${{ github.event_name == 'workflow_dispatch' && inputs.use_environment_plan == true }}
      useEnvironmentApply:   ${{ github.event_name == 'push' || (github.event_name == 'workflow_dispatch' && inputs.use_environment_apply == true) }}
      useEnvironmentDestroy: ${{ github.event_name == 'workflow_dispatch' && inputs.use_environment_destroy == true }}

    secrets:
      AZURE_CLIENT_ID:       ${{ secrets.AZURE_CLIENT_ID }}
      AZURE_TENANT_ID:       ${{ secrets.AZURE_TENANT_ID }}
      AZURE_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
```

---

# 🎯 11. CI/CD DECISION TABLE (VERY IMPORTANT)

| Event | Init | Plan | Apply | Destroy |
|-------|------|-------|--------|----------|
| PR | Yes | Yes | ❌ No | ❌ No |
| Push | Yes | Yes | ✔ Yes (Approval Required) | ❌ No |
| workflow_dispatch | Optional | Optional | Optional | Optional |

---

# 🛡️ 12. ENVIRONMENT PROTECTION STRATEGY

Recommended reviewers:
- DevOps Team  
- Architects  
- Leads  

Prod should require:
✔ Apply approval  
✔ Destroy approval  

---

# 🔐 13. STATE PROTECTION BEST PRACTICES

- Enable soft delete on storage account  
- Enable versioning  
- Enable blob immutability (optional)  
- Use separate container per environment  

---

# 🚀 14. SELF-HOSTED RUNNERS

Advantages:
- Faster plans  
- Private network access  
- Install Terraform/Azure CLI versions you want  
- No GitHub shared runner rate limits  

---

# 🧪 15. TESTING THE PIPELINE (End-to-End)

### Step 1: Create PR  
Plan runs → Review → Merge

### Step 2: Merge  
Push triggers → Full pipeline runs → Apply pauses

### Step 3: Approve Apply  
Infrastructure updates safely

### Step 4: Destroy Only via workflow_dispatch  
Safe, manual, gated

---

# 🧠 16. TROUBLESHOOTING (Important)

### ❌ Apply not running?
Check:
- Environment approval  
- Reviewer permissions  
- Branch protection  
- OIDC binding  

### ❌ Unauthorized for Azure?
Check:
- Federated credential  
- Correct branch/environment binding  
- OIDC login  

### ❌ Destroy not running?
Because destroy only runs in workflow_dispatch.

---

# 📘 17. DOCUMENTATION SUMMARY

This README teaches:
- Terraform basics  
- Modular structure  
- Azure backend  
- OIDC authentication  
- GitHub environment approvals  
- Branch protection  
- PR flow  
- Push behavior  
- workflow_dispatch controls  
- State handling  
- Runner setup  
- End-to-end execution  

---
<details>
<summary style="display: flex; align-items: center; font-size: 3em; font-weight: bold; cursor: pointer;">
<span style="display:inline-block; transform-origin:center; transition:transform .22s;color:#9bd1ff;">▶ &nbsp;</span>
  OVERVIEW
</summary> 

# 🏗️ Terraform Azure Modular Infrastructure + GitHub Actions CI/CD  
## **(Updated for Dynamic Approvals, PR-Only Changes, Protected Branches & Advanced Prod Pipelines)**

A **production-grade Infrastructure as Code (IaC)** architecture using **Terraform + Azure**, fully automated using **GitHub Actions**, supporting multi-environment deployment pipelines:

**Dev → QA → Test → UAT → Prod**

This version includes major enhancements:
- 🔥 Dynamic approval toggles (Init/Plan/Apply/Destroy)
- 🔒 Branch protection & PR-only workflow
- 🔁 PR Plan-only → Merge → Push Apply-with-Approval
- 📦 Multi-environment backend with tfvars
- 🚀 Self-hosted runners + OIDC secure Azure login  
- 🧠 Full control via workflow_dispatch toggles  

---

# 🧭 High-Level Architecture

```
Developer Commit / PR
        │
        ▼
Pull Request (Plan Only)
        │
        ▼
Approval + Merge
        │
        ▼
Push to Main → Full Pipeline
        │
        ▼
Init → Fmt → Validate → Plan
        │
        ▼
Apply (Approval Required via Environment Protection)
        │
        ▼
Azure Infra Updated
```

---

# 🧱 Terraform Modular Infrastructure

## 🚀 Key Features
- Fully **modular** design  
- Reusable modules for RG, VNet, NSG, VM, LB, SQL  
- `for_each` based scalable resource creation  
- **Remote backend** using Azure Storage  
- Clean variable separation using `variables.tf` and environment-based `.tfvars`  
- CI/CD optimized folder structure  

---

# 📁 Directory Structure

```
infra/
├── main.tf
├── provider.tf
├── variables.tf
├── terraform.tfvars
├── outputs.tf
└── modules/
    ├── resourceGroup/
    ├── networking/
    ├── virtual_machine/
    ├── database/
    └── loadBalancer/
```

---

# ⚙️ CI/CD PIPELINE (Fully Updated & Improved)

We now have **3 modes** of execution:

| Mode | Trigger | Behavior |
|------|---------|-----------|
| **PR** | pull_request | 🔍 *Plan Only* (No apply) |
| **Push (main)** | merge to main | 🚀 Full pipeline until Apply → *Apply requires Approval* |
| **workflow_dispatch** | manual | 🧠 Run any stage (Init/Plan/Apply/Destroy) with/without approval |

---

# 🔐 Branch Protection (MANDATORY)

To ensure production safety:

### 🚫 No one can push directly to `main`  
Developers must:
1. Create a PR  
2. PR runs **Plan-only** workflow  
3. Reviewers approve  
4. Merge allowed  
5. Push workflow runs with controlled Apply  

### Configure:
- Require PR review  
- Require status checks → “plan” job must pass  
- Restrict direct pushes  
- Optional: Require signed commits  

This creates a **secure GitOps-style deployment**.

---

# 🔁 PR vs PUSH — Exact Behavior

### 🟦 PULL REQUEST (Safe Mode)
- Runs: **Init → Validate → Plan**
- No Apply  
- No Destroy  
- Fast feedback for reviewers

### 🟩 PUSH (Merge to Main)
- Runs: **Init → Validate → Plan → Apply**
- BUT Apply pauses waiting for GitHub **Environment Approval**

### 🟧 workflow_dispatch (Full Control)
Using:
```
do_init
do_plan
do_apply
do_destroy
use_environment_init
use_environment_plan
use_environment_apply
use_environment_destroy
```
You control:
- What stages run  
- Which stages need approval  
- Destroy allowed only via dispatch  

---

# 🧩 UPDATED PROD WORKFLOW (FINAL)

```yaml
name: prod

on:
  push:
    branches:
      - main
    paths:
      - 'environments/prod.tfvars'

  pull_request:
    branches:
      - main
    paths:
      - 'environments/prod.tfvars'

  workflow_dispatch:
    inputs:
      use_environment_init:    { type: boolean, default: false }
      do_init:                 { type: boolean, default: false }

      use_environment_plan:    { type: boolean, default: false }
      do_plan:                 { type: boolean, default: false }

      use_environment_apply:   { type: boolean, default: false }
      do_apply:                { type: boolean, default: false }

      use_environment_destroy: { type: boolean, default: false }
      do_destroy:              { type: boolean, default: false }

permissions:
  contents: read
  id-token: write

concurrency:
  group: prod-tf
  cancel-in-progress: false

jobs:
  call:
    uses: ./.github/workflows/terraform-multi.yml
    with:
      environment:  prod
      tfvars_file:  environments/prod.tfvars
      rgname:       ritkargv
      saname:       ritkasav
      scname:       ritkascv
      key:          prod.tfstate

      runInit:     ${{ github.event_name != 'pull_request' && (github.event_name == 'push' || inputs.do_init == true) }}
      runPlan:     ${{ github.event_name == 'pull_request' || github.event_name == 'push' || inputs.do_plan == true }}
      runApply:    ${{ github.event_name == 'push' || inputs.do_apply == true }}
      runDestroy:  ${{ github.event_name == 'workflow_dispatch' && inputs.do_destroy == true }}

      useEnvironmentInit:    ${{ github.event_name == 'workflow_dispatch' && inputs.use_environment_init == true }}
      useEnvironmentPlan:    ${{ github.event_name == 'workflow_dispatch' && inputs.use_environment_plan == true }}
      useEnvironmentApply:   ${{ github.event_name == 'push' || (github.event_name == 'workflow_dispatch' && inputs.use_environment_apply == true) }}
      useEnvironmentDestroy: ${{ github.event_name == 'workflow_dispatch' && inputs.use_environment_destroy == true }}

    secrets:
      AZURE_CLIENT_ID:       ${{ secrets.AZURE_CLIENT_ID }}
      AZURE_TENANT_ID:       ${{ secrets.AZURE_TENANT_ID }}
      AZURE_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
```

---

# 🧭 UPDATED WORKFLOW LOGIC DIAGRAM

```
          ┌──────────────┐
          │ Pull Request │
          └──────┬───────┘
                 ▼
     Init → Validate → Plan
                 │
            (No Apply)
                 ▼
        Reviewer Approves
                 ▼
          Merge to Main
                 ▼
          ┌───────────┐
          │ Push CI   │
          └─────┬─────┘
                ▼
Init → Validate → Plan → Apply (Approval Required)
```

---

# 🔐 Azure OIDC + Federated Credentials

- Passwordless authentication  
- No secrets stored  
- Secure identity federation  
- Environment-based protection  

---
</details> </div>

---------------------
---------------------
<details>
<summary style="display: flex; align-items: center; font-size: 3em; font-weight: bold; cursor: pointer;">
<span style="display:inline-block; transform-origin:center; transition:transform .22s;color:#9bd1ff;">▶ &nbsp;</span>
  Good To Know Steps
</summary> 

## 🔐  Azure App Registration and Federated Credential Setup

This section explains how to securely connect **GitHub Actions → Azure Portal** using **OpenID Connect (OIDC)** and **Federated Credentials**.

### **Step 1: Create App Registration in Azure AD**
1. Go to **Azure Portal → Azure Active Directory → App registrations**
2. Click **New registration**
3. Fill details:
   - Name: `github-oidc-terraform-app`
   - Supported account type: *Accounts in this organizational directory only*
   - Redirect URI: Leave blank
4. Click **Register**
5. Copy the **Application (client) ID** and **Directory (tenant) ID**

---

### **Step 2: Assign Role to Your App**
1. Go to your **Azure Subscription → Access Control (IAM) → Add role assignment**
2. Choose a role (e.g., `Contributor`)
3. Select **Members → Assign access to User, Group, or Service Principal**
4. Find and select your **App Registration**
5. Click **Review + Assign**

---

### **Step 3: Configure Federated Credentials**
1. Open your App Registration → **Certificates & Secrets → Federated Credentials**
2. Click **Add Credential**
3. Fill in details:

| Field | Description |
|--------|-------------|
| **Federated credential scenario** | GitHub Actions deploying Azure resources |
| **Organization** | Your GitHub Organization name |
| **Repository** | Your repository name |
| **Entity Type** | Choose Environment or Branch |
| **Environment/Branch Name** | Example: `prod` or `main` |
| **Name** | Example: `prod-deploy-oidc` |

4. Click **Add**

**Note:** If user doesn’t see that option, they can manually choose “Other” and fill the repo/org details

---

### 💡 **Branch vs Environment — When and Why**

When creating **Federated Credentials** in your Azure App Registration, Azure needs to know **“from where GitHub will send identity tokens”**.  
That’s where you must choose **either a Branch or an Environment**, depending on how your pipeline is triggered.

#### 🧩 1. **Branch-Based Federation (Automatic CI/CD)**

✅ **Use this when your workflows run automatically on every code push or PR.**

**Example Use Case:**
- You want Terraform to plan/deploy automatically every time someone pushes to `main`, `dev`, or `feature/*` branch.  
- No manual approval is needed — pipeline runs instantly.

**Azure Setup:**
- In Federated Credential setup:
  - Choose **Entity Type:** `Branch`
  - Enter **Branch name:** `main` or `dev`
- Azure will trust GitHub tokens coming **only from that branch**.

**GitHub Example:**
```yaml
on:
  push:
    branches:
      - main
      - dev
```

🧠 So here, as soon as you push — OIDC auth + Terraform runs automatically.  

---

#### 🧱 2. **Environment-Based Federation (Manual Approval Flow)**

✅ **Use this when you need manual approvals before applying or destroying infrastructure.**

**Example Use Case:**
- You have environments like `dev`, `qa`, `prod`.
- You want `terraform plan` to run automatically, but `terraform apply` should wait for approval.

**Azure Setup:**
- In Federated Credential setup:
  - Choose **Entity Type:** `Environment`
  - Enter **Environment name:** `prod` or `qa`
- Azure will now only trust GitHub tokens **when the job is tied to that environment**.

**GitHub Example:**
```yaml
jobs:
  apply:
    environment:
      name: prod
    runs-on: ubuntu-latest
```

🧠 Here, when the job reaches `environment: prod`,  
GitHub sends an approval request to reviewers → once approved → OIDC token is validated → job executes.

---

#### ⚖️ **Summary — Which One Should You Use?**

| Scenario | Entity Type | When to Use |
|-----------|--------------|--------------|
| Continuous Integration (auto deploy on push) | **Branch** | Dev/Test pipelines that run frequently |
| Controlled Deployment (manual approval needed) | **Environment** | QA/Prod pipelines that need approval |

💬 **Rule of Thumb:**  
- Use **Branch** for speed & automation.  
- Use **Environment** for safety & compliance.

---

### **Step 4: Verify OIDC Authentication in Workflow**
Example GitHub Action step:

```yaml
- name: Azure Login via OIDC
  uses: azure/login@v1
  with:
    client-id: ${{ secrets.AZURE_CLIENT_ID }}
    tenant-id: ${{ secrets.AZURE_TENANT_ID }}
    subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
```

✅ Once this step succeeds, your workflow is authenticated to Azure via OIDC.

---

### **Step 5: Workflow Execution Flow**
1. Push code or trigger the workflow.
2. GitHub sends an OIDC token to Azure.
3. Azure validates it using the Federated Credential.
4. If valid → authentication succeeds → Terraform runs securely.

---

## 🧱 Terraform Deployment Flow with Manual Approval

Typical GitHub Actions Workflow:

```yaml
jobs:
  terraform-apply:
    environment:
      name: prod
      url: https://portal.azure.com
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Login to Azure
        uses: azure/login@v1
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2

      - name: Terraform Init & Plan
        run: |
          terraform init
          terraform plan

      - name: Terraform Apply (Manual Approval Required)
        run: terraform apply -auto-approve
```

🧠 The `environment` block enforces **manual approval** before `apply` or `destroy` executes.

---

## 🎯 Important Points

✅ Secure GitHub-to-Azure connection using **OIDC** (no passwords).  
✅ Enforced **manual approval** with environments.  
✅ Centralized **secret management** via GitHub Actions.  
✅ Fully automated **Terraform deployment** workflow.

---



## 🔐 Environment Protection & Manual Approvals (Step-by-Step Guide)

> We use **GitHub Environments** to enforce **manual approvals** for critical stages like `apply` and `destroy`.  
> When a workflow job references an environment, GitHub automatically pauses the job and sends an approval request to the configured reviewers.  
> The job resumes only after one or more reviewers approve the request.

---

### 🪜 Step-by-Step Setup

#### 1. Add Collaborators / Teams
- Go to your repository → **Settings → Collaborators & Teams**.  
- Add the users or teams who will act as approvers for environment deployments.  
- (Recommended) Create a GitHub Team (e.g., `infra-approvers`) to manage permissions easily.

#### 2. Create Environments
- Go to **Settings → Environments → New Environment**.  
- Create a separate environment for each stage:  
  `dev`, `qa`, `test`, `uat`, `prod`, etc.  
- Each environment should represent a logical stage in your deployment pipeline.

#### 3. Configure Protection Rules and Reviewers
- Click on each environment name → set **Protection Rules**.  
- Under **Required reviewers**, select the collaborators or teams added earlier.  
- Optionally, configure:
  - **Wait timer** (delay before auto-deployment),
  - **Deployment branch policies**, and
  - **Minimum number of required reviewers**.

#### 4. Add Environment Secrets (optional but recommended)
- Under each environment, go to **Secrets → Add Secret**.  
- Store sensitive data (e.g., credentials, API keys) specific to that environment.  
- These secrets are only accessible by jobs that use this environment.

#### 5. Link Workflow Jobs to Environments
In your GitHub Actions workflow (e.g., `terraform-multi.yaml`), define the `environment` key in jobs that require approval.


## 🔑 GitHub Secrets Configuration (for Terraform + Azure OIDC)

This project uses **GitHub Secrets** to store sensitive credentials required for authentication and deployment via Terraform.

Secrets are **encrypted** and securely managed by GitHub. They can be defined either:
- At the **Repository level** (accessible by all workflows)
- Or at the **Environment level** (restricted to specific stages like `dev`, `qa`, `prod`)

---

### 🧱 Required Secrets

The following secrets are mandatory for Azure-based Terraform authentication (via OIDC):

| Secret Name | Description |
|--------------|-------------|
| `AZURE_CLIENT_ID` | The Azure AD App (Service Principal) client ID |
| `AZURE_TENANT_ID` | The Azure Active Directory tenant ID |
| `AZURE_SUBSCRIPTION_ID` | The Azure subscription ID used for deployment |

---

### ⚙️ How to Add Secrets (Step-by-Step)

#### Step 1 — Navigate to Secrets
1. Go to your GitHub repository.  
2. Click on **Settings → Secrets and variables → Actions**.

#### Step 2 — Add Repository Secrets
1. Under the **Repository secrets** section, click on **New repository secret**.
2. Add each of the following secrets one by one:
   - **Name:** `AZURE_CLIENT_ID` → **Value:** *Your Azure App’s Client ID*  
   - **Name:** `AZURE_TENANT_ID` → **Value:** *Your Azure Tenant ID*  
   - **Name:** `AZURE_SUBSCRIPTION_ID` → **Value:** *Your Azure Subscription ID*
3. Click **Add secret** after each entry.

Once saved, the secrets appear under the repository secrets list —  
you’ll see small lock icons 🔒 indicating they’re encrypted and secure.

#### Step 3 — (Optional) Environment Secrets
If you use **GitHub Environments** (e.g., `dev`, `qa`, `prod`), you can add environment-specific secrets too:
1. Go to **Settings → Environments → [Select environment] → Manage environment secrets**.  
2. Add secrets specific to that environment (for example, separate Azure accounts per stage).

---

### 🧩 How Secrets Are Used in the Workflow

In your workflow YAML (e.g., `terraform-multi.yaml`), you reference secrets like this:

```yaml
- name: Azure Login (OIDC)
  uses: azure/login@v2
  with:
    client-id: ${{ secrets.AZURE_CLIENT_ID }}
    tenant-id: ${{ secrets.AZURE_TENANT_ID }}
    subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
```




### 🧠 Best Practices for Secure Secret Management

To ensure your CI/CD pipeline and infrastructure remain secure and compliant, always follow these recommended practices:

---

#### 🔒 1. Use Environment-Level Secrets
- Prefer **environment-level secrets** instead of global repository secrets.  
- This ensures tighter access control — for example:
  - `dev` → test credentials  
  - `qa` → staging credentials  
  - `prod` → real production credentials  
- Environment secrets can only be accessed by jobs running in that environment.

---

#### ♻️ 2. Regularly Rotate Your Credentials
- Periodically **regenerate Azure credentials** (App registrations, service principals).  
- Update them immediately in your GitHub secrets.  
- This minimizes the risk of leaked or stale credentials being reused.

---

#### 🚫 3. Never Expose Secrets in Logs
- Avoid using `echo`, `print`, or `terraform output` commands that might reveal secrets.  
- GitHub automatically masks secrets in logs, but avoid printing any variable containing them.  
- Example of what **not** to do:
  ```yaml
  - run: echo "Client ID: ${{ secrets.AZURE_CLIENT_ID }}"  # ❌ Unsafe
---

#### 🧍‍♂️ 4. Restrict Secret Access & Editing

Keeping your secrets secure also means **controlling who can manage them**. Follow these steps:

- ✅ **Allow only trusted collaborators or admins** to edit secrets.  
  This limits potential security risks from unauthorized changes.

- ⚙️ Navigate to **Repository → Settings → Manage Access**  
  Here you can view and modify collaborator permissions.

- 🔁 **Review access regularly** — remove inactive users or anyone who no longer needs secret management privileges.

- 🔐 Keep a minimal privilege policy — “**least privilege principle**” always applies.

---

#### 🧰 5. Validate Before Deploying

Before you deploy to production, make sure all configurations and secrets are valid:

- 🧪 **Test your workflows in a non-production environment** first (like `dev` or `qa`).  
  This prevents accidental deployments or resource destruction in live systems.

- 📋 Run `terraform plan` before `terraform apply`.  
  This checks authentication, access roles, and infrastructure changes without making modifications.

- 🕵️‍♂️ Validate all Azure credentials (Client ID, Tenant ID, Subscription ID)  
  to ensure they match the correct environment setup.





## 🔐 Security Practices
- `.gitignore` excludes `*.tfstate`, `terraform.tfvars`, and `.terraform/`  
- Secrets never committed to code  
- Each environment isolated with separate state files  

---
</details> </div>

---
---

## 👨‍💻 Author

**_[Ritesh Sharma](https://www.linkedin.com/in/hrutviatri/)_**  
💼 *DevOps Engineer | Azure | Terraform | CI/CD | Docker | Kubernetes*  

[![LinkedIn](https://img.shields.io/badge/LinkedIn-0A66C2?style=for-the-badge&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/hrutviatri/)
[![GitHub](https://img.shields.io/badge/GitHub-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/hrutviatri)

---

## 📜 License
This project is licensed under the **MIT License**.  
You are free to use and modify for educational and personal purposes.

---

> 🧩 *“Code privately. Deploy publicly. Automate everything.”*
