# =============================================================================
# Data Sources
# =============================================================================

# Get the Azure DevOps project
data "azuredevops_project" "project" {
  name = var.project_name
}

# Get the template repository
data "azuredevops_git_repository" "template" {
  project_id = data.azuredevops_project.project.id
  name       = var.template_repository_name
}

# Check if the service endpoint for the template repo already exists using az cli
# Returns the service endpoint ID if found, empty string otherwise
data "external" "check_service_endpoint" {
  program = ["bash", "-c", <<-EOT
    ENDPOINT_ID=$(az devops service-endpoint list \
      --organization "$AZDO_ORG_SERVICE_URL" \
      --project "${var.project_name}" \
      --query "[?name=='sc-template-repo-${var.template_repository_name}'].id | [0]" \
      -o tsv 2>/dev/null || echo "")
    
    if [ -n "$ENDPOINT_ID" ] && [ "$ENDPOINT_ID" != "null" ]; then
      echo "{\"id\": \"$ENDPOINT_ID\", \"exists\": \"true\"}"
    else
      echo "{\"id\": \"\", \"exists\": \"false\"}"
    fi
  EOT
  ]
}
