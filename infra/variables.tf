variable "project" {
  description = "Nom du projet, utilisé dans les noms de ressources et les tags."
  type        = string
  default     = "devsecops-serverless"
}

variable "owner" {
  description = "Valeur du tag Owner."
  type        = string
  default     = "amal-bkhb"
}

variable "environment" {
  description = "Environnement de déploiement."
  type        = string
  default     = "dev"
}

variable "region" {
  description = "Région AWS. Seule eu-west-3 est autorisée."
  type        = string
  default     = "eu-west-3"

  validation {
    condition     = var.region == "eu-west-3"
    error_message = "Seule la région eu-west-3 (Paris) est autorisée."
  }
}
