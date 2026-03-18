# =============================================================================
# Azure DevOps Repository Setup from Template
# =============================================================================
# This Terraform configuration:
# 1. Pulls the latest commit from a template repository's main branch
# 2. Creates a new repository with the template contents
# 3. Creates stage and dev branches from main
# 4. Creates developers and approvers teams
# =============================================================================

terraform {
  required_version = ">= 1.0.0"

  required_providers {
    azuredevops = {
      source  = "microsoft/azuredevops"
      version = ">= 1.0.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9.0"
    }
  }

  backend "azurerm" {}
}

# =============================================================================
# Provider Configuration
# =============================================================================
# Authentication via OIDC (Workload Identity Federation) in Azure Pipelines.
# Required environment variables:
# - AZDO_ORG_SERVICE_URL: Your Azure DevOps organization URL
# - AZDO_CLIENT_ID: Service principal/managed identity client ID
# - AZDO_TENANT_ID: Azure AD tenant ID
# - AZDO_USE_OIDC: Set to true for OIDC authentication
# - SYSTEM_ACCESSTOKEN: Pipeline system access token
# - SYSTEM_OIDCREQUESTURI: OIDC request URI (auto-populated in Azure Pipelines)
# =============================================================================

provider "azuredevops" {
  # Authentication is handled via environment variables
}
