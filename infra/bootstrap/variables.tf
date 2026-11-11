variable "region" {
  type    = string
  default = "eu-west-3"

  validation {
    condition     = var.region == "eu-west-3"
    error_message = "Seule la région eu-west-3 (Paris) est autorisée."
  }
}

variable "project" {
  type    = string
  default = "devsecops-serverless"
}

variable "owner" {
  type    = string
  default = "amal-bkhb"
}

variable "github_repo" {
  description = "Dépôt autorisé à utiliser OIDC, au format proprietaire/depot"
  type        = string
  default     = "amal-bkhb/devsecops-serverless-aws"
}
