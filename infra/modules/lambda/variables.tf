variable "name_prefix" {
  description = "Préfixe des noms de fonctions."
  type        = string
}

variable "role_arns" {
  description = "Nom court de chaque fonction => ARN de son rôle IAM dédié."
  type        = map(string)
}

variable "package_path" {
  description = "Chemin du paquet de déploiement construit par scripts/build_lambda.sh."
  type        = string
}

variable "table_name" {
  description = "Nom de la table DynamoDB, transmis aux fonctions par variable d'environnement."
  type        = string
}

variable "log_retention_days" {
  description = "Durée de conservation des journaux."
  type        = number
  default     = 14

  validation {
    condition     = var.log_retention_days > 0 && var.log_retention_days <= 30
    error_message = "La rétention doit être comprise entre 1 et 30 jours."
  }
}
