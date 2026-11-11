variable "github_owner_id" {
  description = "Identifiant numérique immuable du propriétaire GitHub (claim sub)"
  type        = string
  default     = "210732060"
}

variable "github_repo_id" {
  description = "Identifiant numérique immuable du dépôt GitHub (claim sub)"
  type        = string
  default     = "1393875523"
}

locals {
  gh_owner      = split("/", var.github_repo)[0]
  gh_repo       = split("/", var.github_repo)[1]
  gh_sub_prefix = "repo:${local.gh_owner}@${var.github_owner_id}/${local.gh_repo}@${var.github_repo_id}"
}
