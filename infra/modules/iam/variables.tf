variable "name_prefix" {
  description = "Préfixe des noms de fonctions et de rôles (ex. devsecops-serverless-dev)."
  type        = string
}

variable "region" {
  description = "Région des log groups."
  type        = string
}

variable "table_arn" {
  description = "ARN exact de la table DynamoDB."
  type        = string
}

variable "kms_key_arn" {
  description = "ARN exact de la CMK qui chiffre la table."
  type        = string
}

variable "functions" {
  description = "Nom court de chaque Lambda => l'unique action DynamoDB dont elle a besoin."
  type        = map(string)

  validation {
    condition     = alltrue([for action in values(var.functions) : can(regex("^dynamodb:[A-Za-z]+$", action))])
    error_message = "Chaque fonction doit avoir exactement une action DynamoDB précise (ex. dynamodb:PutItem). Aucun joker autorisé."
  }
}
