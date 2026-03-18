# =============================================================================
# Outputs
# =============================================================================

output "project_id" {
  description = "The ID of the Azure DevOps project"
  value       = data.azuredevops_project.project.id
}

output "template_repository_id" {
  description = "The ID of the template repository"
  value       = data.azuredevops_git_repository.template.id
}

output "target_repository_id" {
  description = "The ID of the newly created target repository"
  value       = azuredevops_git_repository.target.id
}

output "target_repository_name" {
  description = "The name of the newly created target repository"
  value       = azuredevops_git_repository.target.name
}

output "target_repository_url" {
  description = "The clone URL of the newly created target repository"
  value       = azuredevops_git_repository.target.remote_url
}

output "target_repository_web_url" {
  description = "The web URL of the newly created target repository"
  value       = azuredevops_git_repository.target.web_url
}

output "branch_stage" {
  description = "The stage branch name"
  value       = "stage"
}

output "branch_dev" {
  description = "The dev branch name"
  value       = "dev"
}

output "group_developers_id" {
  description = "The ID of the developers group"
  value       = azuredevops_group.developers.id
}

output "group_developers_name" {
  description = "The name of the developers group"
  value       = azuredevops_group.developers.display_name
}

output "group_approvers_id" {
  description = "The ID of the approvers group"
  value       = azuredevops_group.approvers.id
}

output "group_approvers_name" {
  description = "The name of the approvers group"
  value       = azuredevops_group.approvers.display_name
}

# =============================================================================
# Branch Policy Outputs
# =============================================================================

output "branch_policies" {
  description = "Summary of branch policies applied"
  value = {
    main = {
      min_reviewers      = azuredevops_branch_policy_min_reviewers.main.id
      comment_resolution = azuredevops_branch_policy_comment_resolution.main.id
      merge_types        = azuredevops_branch_policy_merge_types.main.id
    }
    stage = {
      min_reviewers      = azuredevops_branch_policy_min_reviewers.stage.id
      comment_resolution = azuredevops_branch_policy_comment_resolution.stage.id
      merge_types        = azuredevops_branch_policy_merge_types.stage.id
    }
    dev = {
      min_reviewers      = azuredevops_branch_policy_min_reviewers.dev.id
      comment_resolution = azuredevops_branch_policy_comment_resolution.dev.id
      merge_types        = azuredevops_branch_policy_merge_types.dev.id
    }
  }
}
