# Azure DevOps Repository Setup from Template

This Terraform configuration automates the creation of a new Azure DevOps repository from a template repository, including branch creation and group setup.

## Features

- **Repository Creation**: Creates a new repository from a template repository's contents
- **Branch Creation**: Automatically creates `stage` and `dev` branches from `main`
- **Group Setup**: Creates `<repository-name>-developers` and `<repository-name>-approvers` groups

## Prerequisites

1. **Terraform** >= 1.0.0
2. **Azure DevOps Provider** >= 1.0.0
3. **Azure DevOps Permissions**:
   - Read access to the template repository
   - Create repository permissions in the project
   - Create group permissions in the project

## Authentication

The Azure DevOps provider supports multiple authentication methods:

### Option 1: OIDC / Workload Identity Federation (Recommended for Pipelines)

```bash
export AZDO_ORG_SERVICE_URL="https://dev.azure.com/your-organization"
export AZDO_CLIENT_ID="your-client-id"
export AZDO_TENANT_ID="your-tenant-id"
export AZDO_USE_OIDC=true
export SYSTEM_ACCESSTOKEN="<pipeline-token>"
export SYSTEM_OIDCREQUESTURI="<oidc-request-uri>"
```

See the [Azure DevOps Pipeline Setup](#azure-devops-pipeline-setup-with-oidc) section for detailed configuration.

### Option 2: Personal Access Token (PAT)

```bash
export AZDO_ORG_SERVICE_URL="https://dev.azure.com/your-organization"
export AZDO_PERSONAL_ACCESS_TOKEN="your-pat-token"
```

### Running in Azure Pipelines with OIDC

Use the `AzureCLI@2` task with Workload Identity Federation:

```yaml
- task: AzureCLI@2
  displayName: 'Terraform Plan'
  inputs:
    azureSubscription: $(SERVICE_CONNECTION_NAME)
    scriptType: 'bash'
    scriptLocation: 'inlineScript'
    addSpnToEnvironment: true
    useWorkloadIdentityFederation: true
    inlineScript: |
      export ARM_CLIENT_ID=$servicePrincipalId
      export ARM_OIDC_TOKEN=$idToken
      export ARM_TENANT_ID=$tenantId
      export ARM_USE_OIDC=true
      terraform plan -input=false -out=tfplan
  env:
    ARM_SUBSCRIPTION_ID: $(ARM_SUBSCRIPTION_ID)
    AZDO_ORG_SERVICE_URL: $(AZDO_ORG_SERVICE_URL)
    AZDO_CLIENT_ID: $(AZDO_CLIENT_ID)
    AZDO_TENANT_ID: $(AZDO_TENANT_ID)
    AZDO_USE_OIDC: true
    SYSTEM_ACCESSTOKEN: $(System.AccessToken)
    SYSTEM_OIDCREQUESTURI: $(System.OidcRequestUri)
```

## Usage

### 1. Initialize Terraform

```bash
terraform init
```

### 2. Create a variables file

Copy the example file and fill in your values:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
project_name             = "MyProject"
template_repository_name = "template-repo"
target_repository_name   = "my-new-repo"
```

### 3. Plan and Apply

```bash
# Preview changes
terraform plan

# Apply changes
terraform apply
```

## Input Variables

| Name | Description | Type | Required |
|------|-------------|------|----------|
| `project_name` | The name of the Azure DevOps project | `string` | Yes |
| `template_repository_name` | The name of the template repository to clone from | `string` | Yes |
| `target_repository_name` | The name of the new repository to create | `string` | Yes |

## Outputs

| Name | Description |
|------|-------------|
| `project_id` | The ID of the Azure DevOps project |
| `template_repository_id` | The ID of the template repository |
| `target_repository_id` | The ID of the newly created target repository |
| `target_repository_name` | The name of the newly created target repository |
| `target_repository_url` | The clone URL of the newly created target repository |
| `target_repository_web_url` | The web URL of the newly created target repository |
| `branch_stage` | The stage branch name |
| `branch_dev` | The dev branch name |
| `group_developers_id` | The ID of the developers group |
| `group_developers_name` | The name of the developers group |
| `group_approvers_id` | The ID of the approvers group |
| `group_approvers_name` | The name of the approvers group |

## Resources Created

1. **Git Repository** (`azuredevops_git_repository.target`)
   - New repository initialized from the template repository

2. **Git Branches**
   - `stage` branch from `main`
   - `dev` branch from `main`

3. **Groups**
   - `<target-repo-name>-developers`
   - `<target-repo-name>-approvers`

## Example

```hcl
# terraform.tfvars
project_name             = "Platform-Engineering"
template_repository_name = "azure-landing-zone-template"
target_repository_name   = "contoso-alz"
```

This will create:
- Repository: `contoso-alz` (with contents from `azure-landing-zone-template`)
- Branches: `main`, `stage`, `dev`
- Groups: `contoso-alz-developers`, `contoso-alz-approvers`

## Troubleshooting

### Repository import fails

Ensure the Build Service or your PAT has:
- Read access to the template repository
- Contribute permissions to create repositories in the project

### Branch creation fails

The repository must be fully initialized before branches can be created. The `depends_on` blocks handle this automatically.

### Group creation fails

Ensure your identity has Project Administrator permissions in the project.

---

## Azure DevOps Pipeline Setup with OIDC

This section documents requirements and common issues when running this Terraform via Azure DevOps Pipelines with OIDC (Workload Identity Federation).

### Prerequisites

1. **Azure Service Connection** with Workload Identity Federation enabled
2. **Managed Identity or Service Principal** with federated credentials configured
3. **Azure DevOps Variable Group** (`repository-setup-automation`) with required variables

### Variable Group Configuration

Create a variable group named `repository-setup-automation` with:

| Variable | Description | Example |
|----------|-------------|---------|
| `AZDO_ORG_SERVICE_URL` | Azure DevOps organization URL | `https://dev.azure.com/yourorg` |
| `AZDO_CLIENT_ID` | Service principal/managed identity client ID | `...` |
| `AZDO_TENANT_ID` | Azure AD tenant ID | `...` |
| `ARM_SUBSCRIPTION_ID` | Azure subscription for Terraform state storage | `...` |
| `GIT_PAT` | PAT with Code (Read & Status) scope **(secret)** | `xxxx...` |

#### About the GIT_PAT Variable

The `GIT_PAT` is a Personal Access Token used **only for the initial repository import** from the template repository. This is required because the Azure DevOps Import API treats even internal repositories as external Git sources and requires authentication.

**Scope:** The PAT only needs **Code (Read)** and **Code (Status)** permissions - it is used solely to clone the template repository contents during the initial import. After the repository is created, the PAT is no longer used.

**Security Notes:**
- Mark this variable as a **secret** in the variable group
- The PAT is stored in a `azuredevops_serviceendpoint_generic_git` service connection managed by Terraform
- Consider using a service account PAT rather than a personal user's PAT
- The service connection name follows the pattern: `sc-template-repo-<template-repo-name>`

### Pipeline Parameters

When running the pipeline, provide:
- `projectName` - Azure DevOps project name
- `templateRepositoryName` - Source template repository
- `targetRepositoryName` - New repository to create

---

## Common Issues and Solutions

### 1. "Repository does not exist" Error

**Symptom:**
```
Error: Repository with name <repo-name> does not exist in project <project-id>
```

**Cause:** The managed identity/service principal doesn't have proper access to the repository.

**Solution:**
1. Go to **Azure DevOps Organization Settings** → **Users**
2. Find your managed identity and change access level from **Stakeholder** to **Basic**
3. Verify the identity is added to the project as a **Contributor**

> **Important:** Stakeholder access level cannot read Git repositories. Basic access is required.

### 2. "CreateRepository" Permission Error

**Symptom:**
```
TF401027: You need the Git 'CreateRepository' permission to perform this action
```

**Solution:**
1. Go to **Project Settings** → **Repos** → **Repositories**
2. Click **Security** at the "All Repositories" level
3. Find your managed identity
4. Set **Create repository** = **Allow**

### 3. "Edit identity information" Permission Error (Team Creation)

**Symptom:**
```
Access Denied: needs 'Edit identity information' permission in the Identity security namespace
```

**Solution:**
Add the managed identity to the **Project Administrators** group:
1. Go to **Project Settings** → **Permissions**
2. Click **Project Administrators**
3. Add your managed identity as a member

Alternatively, grant specific permissions:
- **Create team**
- **Edit identity information**

### 4. "ARM_SUBSCRIPTION_ID: command not found"

**Symptom:**
```
/azp/agent/_work/_temp/script.sh: line 4: ARM_SUBSCRIPTION_ID: command not found
```

**Cause:** Using `$(ARM_SUBSCRIPTION_ID)` syntax inside bash inline scripts is interpreted as command substitution.

**Solution:** Pass variables via the `env` section, not inline in the script:

```yaml
# Correct approach
- task: AzureCLI@2
  inputs:
    inlineScript: |
      export ARM_CLIENT_ID=$servicePrincipalId
      terraform init
  env:
    ARM_SUBSCRIPTION_ID: $(ARM_SUBSCRIPTION_ID)  # Pass via env section
```

### 5. Data Source "azuredevops_git_repository_branch" Not Supported

**Symptom:**
```
Error: Invalid data source - The provider does not support data source "azuredevops_git_repository_branch"
```

**Solution:** This is a resource type, not a data source. Use the resource directly or reference branches by string:

```hcl
# Use string reference for branch policies
repository_ref = "refs/heads/main"
```

### 6. OIDC Token Not Working

**Symptom:** Authentication errors when accessing Azure DevOps APIs.

**Checklist:**
1. Verify `AZDO_CLIENT_ID` matches the managed identity's **Client ID** (Application ID)
2. Ensure federated credentials are configured on the managed identity
3. Verify the service connection uses **Workload Identity Federation**
4. Check that `SYSTEM_ACCESSTOKEN` and `SYSTEM_OIDCREQUESTURI` are passed to the task

### Required Azure DevOps Permissions Summary

| Permission | Where to Grant | Required For |
|------------|----------------|--------------|
| **Basic access level** | Organization → Users | Reading Git repositories |
| **Read** on repositories | Project Settings → Repos → Security | Reading template repository |
| **Create repository** | Project Settings → Repos → Security | Creating new repositories |
| **Project Administrators** (or specific permissions) | Project Settings → Permissions | Creating teams, editing identity |
| **Contribute** | Project Settings → Repos → Security | Creating branches, branch policies |

---

## Backend Configuration

The Terraform state is stored in Azure Blob Storage. Configure the backend in `terraform.tf`:

```hcl
backend "azurerm" {
  resource_group_name  = "rg-terraform-state"
  storage_account_name = "stterraformstate"
  container_name       = "tfstate"
  key                  = "repository-setup.tfstate"
  use_azuread_auth     = true
}
```

The pipeline automatically configures ARM_* environment variables for OIDC authentication with the backend.