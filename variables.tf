# =============================================================================
# Input Variables
# =============================================================================

variable "project_name" {
  type        = string
  description = "The name of the Azure DevOps project"

  validation {
    condition     = length(var.project_name) > 0
    error_message = "Project name cannot be empty."
  }
}

variable "template_repository_name" {
  type        = string
  description = "The name of the template repository to clone from"

  validation {
    condition     = length(var.template_repository_name) > 0
    error_message = "Template repository name cannot be empty."
  }
}

variable "target_repository_name" {
  type        = string
  description = "The name of the new repository to create"

  validation {
    condition     = length(var.target_repository_name) > 0
    error_message = "Target repository name cannot be empty."
  }

  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9-_.]*$", var.target_repository_name))
    error_message = "Target repository name must start with an alphanumeric character and can only contain alphanumeric characters, hyphens, underscores, and periods."
  }
}

variable "git_pat" {
  type        = string
  description = "Personal Access Token with Code (Read & Status) scope. Used ONLY for initial repository import from template - not used after repository creation."
  sensitive   = true
}
