data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
}

# Seul le service Lambda peut assumer ces rôles.
data "aws_iam_policy_document" "assume_lambda" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  for_each           = var.functions
  name               = "${var.name_prefix}-${each.key}"
  assume_role_policy = data.aws_iam_policy_document.assume_lambda.json
}

data "aws_iam_policy_document" "lambda" {
  for_each = var.functions

  # L'unique action DynamoDB de cette fonction, sur l'ARN exact de la table.
  statement {
    sid       = "TableAccess"
    actions   = [each.value]
    resources = [var.table_arn]
  }

  # Nécessaire car la table est chiffrée avec une CMK. Limité à cette seule clé.
  statement {
    sid       = "DecryptTableKey"
    actions   = ["kms:Decrypt"]
    resources = [var.kms_key_arn]
  }

  # Écriture uniquement dans le log group de CETTE fonction. Le log group est créé par Terraform
  # (avec une rétention définie), d'où l'absence de logs:CreateLogGroup.
  statement {
    sid       = "OwnLogsOnly"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["arn:aws:logs:${var.region}:${local.account_id}:log-group:/aws/lambda/${var.name_prefix}-${each.key}:*"]
  }
}

resource "aws_iam_role_policy" "lambda" {
  for_each = var.functions
  name     = "least-privilege"
  role     = aws_iam_role.lambda[each.key].id
  policy   = data.aws_iam_policy_document.lambda[each.key].json
}
