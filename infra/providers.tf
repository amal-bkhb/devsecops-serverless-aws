provider "aws" {
  region = var.region

  # Tags posés automatiquement sur toutes les ressources taguables (règle OPA n° 1).
  default_tags {
    tags = {
      Project     = var.project
      Owner       = var.owner
      Environment = var.environment
    }
  }
}
