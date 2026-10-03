variable "name_prefix" {
  description = "Préfixe du nom de l'API."
  type        = string
}

variable "routes" {
  description = "Clé de route (\"METHODE /chemin\") => nom court de la fonction qui la traite."
  type        = map(string)
}

variable "invoke_arns" {
  description = "Nom court de chaque fonction => ARN d'invocation."
  type        = map(string)
}

variable "function_names" {
  description = "Nom court de chaque fonction => nom complet de la fonction Lambda."
  type        = map(string)
}

variable "throttling_rate_limit" {
  description = "Requêtes par seconde autorisées en régime normal."
  type        = number
  default     = 5
}

variable "throttling_burst_limit" {
  description = "Requêtes autorisées en pic."
  type        = number
  default     = 10
}

variable "log_retention_days" {
  description = "Durée de conservation des journaux d'accès."
  type        = number
  default     = 14

  validation {
    condition     = var.log_retention_days > 0 && var.log_retention_days <= 30
    error_message = "La rétention doit être comprise entre 1 et 30 jours."
  }
}
