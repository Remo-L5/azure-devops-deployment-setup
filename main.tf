# =============================================================================
# Service Connection for Template Repository Access
# =============================================================================

# Create a Generic Git service connection for importing from template repos
# Only create if it doesn't already exist
resource "azuredevops_serviceendpoint_generic_git" "template_access" {
  count = data.external.check_service_endpoint.result.exists == "true" ? 0 : 1

  project_id            = data.azuredevops_project.project.id
  repository_url        = data.azuredevops_git_repository.template.remote_url
  username              = "git"
  password              = var.git_pat
  service_endpoint_name = "sc-template-repo-${var.template_repository_name}"
  description           = "Service connection for importing from ${var.template_repository_name}"
}

# Local value to reference either the existing or newly created service endpoint
locals {
  service_endpoint_id = (
    data.external.check_service_endpoint.result.exists == "true"
    ? data.external.check_service_endpoint.result.id
    : azuredevops_serviceendpoint_generic_git.template_access[0].id
  )
}

# =============================================================================
# Resources
# =============================================================================

# Create the new target repository initialized from template
resource "azuredevops_git_repository" "target" {
  project_id = data.azuredevops_project.project.id
  name       = var.target_repository_name

  initialization {
    init_type             = "Import"
    source_type           = "Git"
    source_url            = data.azuredevops_git_repository.template.remote_url
    service_connection_id = local.service_endpoint_id
  }

  lifecycle {
    ignore_changes = [
      initialization
    ]
  }
}

# Wait for the repository import to complete before creating branches
# Import operations are asynchronous - the API returns success before git refs are available
resource "time_sleep" "wait_for_repo_import" {
  depends_on      = [azuredevops_git_repository.target]
  create_duration = "60s"

  # Re-trigger if the repository is recreated
  triggers = {
    repository_id = azuredevops_git_repository.target.id
  }
}

# Create stage branch from main
resource "azuredevops_git_repository_branch" "stage" {
  depends_on    = [time_sleep.wait_for_repo_import]
  repository_id = azuredevops_git_repository.target.id
  name          = "stage"
  ref_branch    = "main"
}

# Wait before creating dev branch
resource "time_sleep" "wait_before_dev_branch" {
  depends_on      = [azuredevops_git_repository_branch.stage]
  create_duration = "30s"
}

# Create dev branch from main
resource "azuredevops_git_repository_branch" "dev" {
  depends_on    = [time_sleep.wait_before_dev_branch]
  repository_id = azuredevops_git_repository.target.id
  name          = "dev"
  ref_branch    = "main"
}

# =============================================================================
# Groups
# =============================================================================

# Create the developers group
resource "azuredevops_group" "developers" {
  scope        = data.azuredevops_project.project.id
  display_name = "${var.target_repository_name}-developers"
  description  = "Developers group for ${var.target_repository_name} repository"
}

# Create the approvers group
resource "azuredevops_group" "approvers" {
  scope        = data.azuredevops_project.project.id
  display_name = "${var.target_repository_name}-approvers"
  description  = "Approvers group for ${var.target_repository_name} repository"
}

# =============================================================================
# Repository Permissions
# =============================================================================

# Developers group - can contribute but cannot create PRs
resource "azuredevops_git_permissions" "developers" {
  project_id    = data.azuredevops_project.project.id
  repository_id = azuredevops_git_repository.target.id
  principal     = azuredevops_group.developers.descriptor

  permissions = {
    GenericRead           = "Allow"
    GenericContribute     = "Allow"
    CreateBranch          = "Allow"
    PullRequestContribute = "Deny"
  }
}

# Approvers group - can contribute and create PRs
resource "azuredevops_git_permissions" "approvers" {
  project_id    = data.azuredevops_project.project.id
  repository_id = azuredevops_git_repository.target.id
  principal     = azuredevops_group.approvers.descriptor

  permissions = {
    GenericRead           = "Allow"
    GenericContribute     = "Allow"
    CreateBranch          = "Allow"
    PullRequestContribute = "Allow"
  }
}

# =============================================================================
# Branch Policies - Main Branch
# =============================================================================

# Minimum reviewers policy for main branch
resource "azuredevops_branch_policy_min_reviewers" "main" {
  project_id = data.azuredevops_project.project.id

  enabled  = true
  blocking = true

  settings {
    reviewer_count                         = 2
    submitter_can_vote                     = false
    last_pusher_cannot_approve             = true
    allow_completion_with_rejects_or_waits = false
    on_push_reset_approved_votes           = true

    scope {
      repository_id  = azuredevops_git_repository.target.id
      repository_ref = "refs/heads/main"
      match_type     = "Exact"
    }
  }
}

# Comment resolution policy for main branch
resource "azuredevops_branch_policy_comment_resolution" "main" {
  project_id = data.azuredevops_project.project.id

  enabled  = true
  blocking = true

  settings {
    scope {
      repository_id  = azuredevops_git_repository.target.id
      repository_ref = "refs/heads/main"
      match_type     = "Exact"
    }
  }
}

# Merge strategy policy for main branch - squash only
resource "azuredevops_branch_policy_merge_types" "main" {
  project_id = data.azuredevops_project.project.id

  enabled  = true
  blocking = true

  settings {
    allow_squash                  = true
    allow_rebase_and_fast_forward = false
    allow_basic_no_fast_forward   = false
    allow_rebase_with_merge       = false

    scope {
      repository_id  = azuredevops_git_repository.target.id
      repository_ref = "refs/heads/main"
      match_type     = "Exact"
    }
  }
}

# Required approvers policy for main branch
resource "azuredevops_branch_policy_auto_reviewers" "main" {
  project_id = data.azuredevops_project.project.id

  enabled  = true
  blocking = true

  settings {
    auto_reviewer_ids  = [azuredevops_group.approvers.origin_id]
    submitter_can_vote = false
    message            = "Approval required from approvers group"

    scope {
      repository_id  = azuredevops_git_repository.target.id
      repository_ref = "refs/heads/main"
      match_type     = "Exact"
    }
  }
}

# =============================================================================
# Branch Policies - Stage Branch
# =============================================================================

# Minimum reviewers policy for stage branch
resource "azuredevops_branch_policy_min_reviewers" "stage" {
  depends_on = [azuredevops_git_repository_branch.stage]
  project_id = data.azuredevops_project.project.id

  enabled  = true
  blocking = true

  settings {
    reviewer_count                         = 2
    submitter_can_vote                     = false
    last_pusher_cannot_approve             = true
    allow_completion_with_rejects_or_waits = false
    on_push_reset_approved_votes           = true

    scope {
      repository_id  = azuredevops_git_repository.target.id
      repository_ref = "refs/heads/stage"
      match_type     = "Exact"
    }
  }
}

# Comment resolution policy for stage branch
resource "azuredevops_branch_policy_comment_resolution" "stage" {
  project_id = data.azuredevops_project.project.id

  enabled  = true
  blocking = true

  settings {
    scope {
      repository_id  = azuredevops_git_repository.target.id
      repository_ref = "refs/heads/stage"
      match_type     = "Exact"
    }
  }
}

# Merge strategy policy for stage branch - squash only
resource "azuredevops_branch_policy_merge_types" "stage" {
  project_id = data.azuredevops_project.project.id

  enabled  = true
  blocking = true

  settings {
    allow_squash                  = true
    allow_rebase_and_fast_forward = false
    allow_basic_no_fast_forward   = false
    allow_rebase_with_merge       = false

    scope {
      repository_id  = azuredevops_git_repository.target.id
      repository_ref = "refs/heads/stage"
      match_type     = "Exact"
    }
  }
}

# Required approvers policy for stage branch
resource "azuredevops_branch_policy_auto_reviewers" "stage" {
  depends_on = [azuredevops_git_repository_branch.stage]
  project_id = data.azuredevops_project.project.id

  enabled  = true
  blocking = true

  settings {
    auto_reviewer_ids  = [azuredevops_group.approvers.origin_id]
    submitter_can_vote = false
    message            = "Approval required from approvers group"

    scope {
      repository_id  = azuredevops_git_repository.target.id
      repository_ref = "refs/heads/stage"
      match_type     = "Exact"
    }
  }
}

# =============================================================================
# Branch Policies - Dev Branch
# =============================================================================

# Minimum reviewers policy for dev branch
resource "azuredevops_branch_policy_min_reviewers" "dev" {
  depends_on = [azuredevops_git_repository_branch.dev]
  project_id = data.azuredevops_project.project.id

  enabled  = true
  blocking = true

  settings {
    reviewer_count                         = 2
    submitter_can_vote                     = false
    last_pusher_cannot_approve             = true
    allow_completion_with_rejects_or_waits = false
    on_push_reset_approved_votes           = true

    scope {
      repository_id  = azuredevops_git_repository.target.id
      repository_ref = "refs/heads/dev"
      match_type     = "Exact"
    }
  }
}

# Comment resolution policy for dev branch
resource "azuredevops_branch_policy_comment_resolution" "dev" {
  project_id = data.azuredevops_project.project.id

  enabled  = true
  blocking = true

  settings {
    scope {
      repository_id  = azuredevops_git_repository.target.id
      repository_ref = "refs/heads/dev"
      match_type     = "Exact"
    }
  }
}

# Merge strategy policy for dev branch - squash only
resource "azuredevops_branch_policy_merge_types" "dev" {
  project_id = data.azuredevops_project.project.id

  enabled  = true
  blocking = true

  settings {
    allow_squash                  = true
    allow_rebase_and_fast_forward = false
    allow_basic_no_fast_forward   = false
    allow_rebase_with_merge       = false

    scope {
      repository_id  = azuredevops_git_repository.target.id
      repository_ref = "refs/heads/dev"
      match_type     = "Exact"
    }
  }
}

# Required approvers policy for dev branch
resource "azuredevops_branch_policy_auto_reviewers" "dev" {
  depends_on = [azuredevops_git_repository_branch.dev]
  project_id = data.azuredevops_project.project.id

  enabled  = true
  blocking = true

  settings {
    auto_reviewer_ids  = [azuredevops_group.approvers.origin_id]
    submitter_can_vote = false
    message            = "Approval required from approvers group"

    scope {
      repository_id  = azuredevops_git_repository.target.id
      repository_ref = "refs/heads/dev"
      match_type     = "Exact"
    }
  }
}
