data "aws_caller_identity" "current" {}

# Clé gérée par le client (CMK) : on contrôle qui peut déchiffrer, et chaque usage est tracé dans CloudTrail.
resource "aws_kms_key" "table" {
  description             = "CMK de la table ${var.table_name}"
  enable_key_rotation     = true # rotation automatique annuelle
  deletion_window_in_days = 7    # délai minimal avant suppression définitive

  # Politique de clé explicite. Le principal est le compte lui-même (et non "*") : l'accès réel
  # est ensuite délégué par des politiques IAM. Dans une politique de clé, Resource "*" désigne
  # uniquement CETTE clé, pas toutes les ressources du compte.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnableAccountAdministration"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      }
    ]
  })
}

resource "aws_kms_alias" "table" {
  name          = "alias/${var.table_name}"
  target_key_id = aws_kms_key.table.key_id
}

resource "aws_dynamodb_table" "tasks" {
  name                        = var.table_name
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "id"
  deletion_protection_enabled = var.deletion_protection

  attribute {
    name = "id"
    type = "S"
  }

  # Chiffrement avec notre CMK (règle OPA n° 4).
  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.table.arn
  }

  # Restauration à n'importe quelle seconde des 35 derniers jours (règle OPA n° 4).
  point_in_time_recovery {
    enabled = true
  }
}
