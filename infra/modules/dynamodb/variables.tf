variable "table_name" {
  description = "Nom de la table DynamoDB."
  type        = string
}

variable "deletion_protection" {
  description = "Empêche la suppression de la table. Désactivé pour un projet de démonstration détruit et recréé."
  type        = bool
  default     = false
}
