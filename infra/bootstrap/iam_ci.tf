locals {
  account_id = data.aws_caller_identity.current.account_id
  app_prefix = "${var.project}-dev"
  oidc_host  = "token.actions.githubusercontent.com"
  state_arn  = aws_s3_bucket.state.arn
  arn_base   = "arn:aws"
}

# ---------------------------------------------------------------------------
# Confiance OIDC : QUI peut endosser chaque rôle
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "trust_apply" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"
      values   = ["repo:${var.github_repo}:ref:refs/heads/main"]
    }
  }
}

data "aws_iam_policy_document" "trust_plan" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"
      values   = ["repo:${var.github_repo}:pull_request"]
    }
  }
}

resource "aws_iam_role" "apply" {
  name                 = "${var.project}-ci-apply"
  description          = "GitHub Actions - deploiement depuis main uniquement"
  assume_role_policy   = data.aws_iam_policy_document.trust_apply.json
  max_session_duration = 3600
}

resource "aws_iam_role" "plan" {
  name                 = "${var.project}-ci-plan"
  description          = "GitHub Actions - plan en lecture seule pour les PR"
  assume_role_policy   = data.aws_iam_policy_document.trust_plan.json
  max_session_duration = 3600
}

# ---------------------------------------------------------------------------
# Rôle APPLY : CE QU'il peut faire (large au départ, à réduire via CloudTrail)
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "apply" {
  statement {
    sid       = "EtatListe"
    actions   = ["s3:ListBucket"]
    resources = [local.state_arn]
  }
  statement {
    sid       = "EtatLectureEcriture"
    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = ["${local.state_arn}/env/*"]
  }
  statement {
    sid       = "EtatVerrou"
    actions   = ["s3:DeleteObject"]
    resources = ["${local.state_arn}/env/*.tflock"]
  }

  statement {
    sid       = "DynamoDB"
    actions   = ["dynamodb:*"]
    resources = ["${local.arn_base}:dynamodb:${var.region}:${local.account_id}:table/${local.app_prefix}-*"]
  }

  statement {
    sid       = "Lambda"
    actions   = ["lambda:*"]
    resources = ["${local.arn_base}:lambda:${var.region}:${local.account_id}:function:${local.app_prefix}-*"]
  }

  statement {
    sid = "RolesApplicatifs"
    actions = [
      "iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:UpdateRole",
      "iam:UpdateAssumeRolePolicy", "iam:TagRole", "iam:UntagRole", "iam:ListRoleTags",
      "iam:PutRolePolicy", "iam:GetRolePolicy", "iam:DeleteRolePolicy",
      "iam:ListRolePolicies", "iam:ListAttachedRolePolicies", "iam:ListInstanceProfilesForRole",
    ]
    resources = ["${local.arn_base}:iam::${local.account_id}:role/${local.app_prefix}-*"]
  }

  statement {
    sid       = "PassRoleVersLambdaUniquement"
    actions   = ["iam:PassRole"]
    resources = ["${local.arn_base}:iam::${local.account_id}:role/${local.app_prefix}-*"]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["lambda.amazonaws.com"]
    }
  }

  statement {
    sid       = "KmsCreation"
    actions   = ["kms:CreateKey", "kms:ListAliases"]
    resources = ["*"]
  }
  statement {
    sid     = "KmsGestion"
    actions = ["kms:*"]
    resources = [
      "${local.arn_base}:kms:${var.region}:${local.account_id}:key/*",
      "${local.arn_base}:kms:${var.region}:${local.account_id}:alias/${local.app_prefix}-*",
    ]
  }

  statement {
    sid     = "Logs"
    actions = ["logs:*"]
    resources = [
      "${local.arn_base}:logs:${var.region}:${local.account_id}:log-group:*${local.app_prefix}*",
      "${local.arn_base}:logs:${var.region}:${local.account_id}:log-group:*${local.app_prefix}*:*",
    ]
  }
  statement {
    sid       = "LogsLecture"
    actions   = ["logs:DescribeLogGroups"]
    resources = ["${local.arn_base}:logs:${var.region}:${local.account_id}:log-group:*"]
  }
  statement {
    sid = "LogsLivraisonApiGateway"
    actions = [
      "logs:CreateLogDelivery", "logs:GetLogDelivery", "logs:UpdateLogDelivery",
      "logs:DeleteLogDelivery", "logs:ListLogDeliveries",
      "logs:PutResourcePolicy", "logs:DescribeResourcePolicies",
    ]
    resources = ["*"]
  }

  statement {
    sid     = "ApiGateway"
    actions = ["apigateway:*"]
    resources = [
      "${local.arn_base}:apigateway:${var.region}::/apis",
      "${local.arn_base}:apigateway:${var.region}::/apis/*",
      "${local.arn_base}:apigateway:${var.region}::/tags/*",
    ]
  }

  # Garde-fou : le rôle apply ne peut JAMAIS toucher à la chaîne de confiance CI
  statement {
    sid     = "InterdireEscaladeVersCI"
    effect  = "Deny"
    actions = ["iam:*"]
    resources = [
      "${local.arn_base}:iam::${local.account_id}:role/${var.project}-ci-*",
      "${local.arn_base}:iam::${local.account_id}:oidc-provider/*",
    ]
  }
  statement {
    sid    = "ProtegerBucketEtat"
    effect = "Deny"
    actions = [
      "s3:DeleteBucket", "s3:PutBucketPolicy", "s3:DeleteBucketPolicy",
      "s3:PutBucketVersioning", "s3:PutEncryptionConfiguration",
      "s3:PutBucketPublicAccessBlock", "s3:PutLifecycleConfiguration",
    ]
    resources = [local.state_arn]
  }
}

resource "aws_iam_role_policy" "apply" {
  name   = "deploiement-application"
  role   = aws_iam_role.apply.id
  policy = data.aws_iam_policy_document.apply.json
}

# ---------------------------------------------------------------------------
# Rôle PLAN : lecture des métadonnées uniquement (+ verrou de l'état)
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "plan" {
  statement {
    sid       = "EtatListe"
    actions   = ["s3:ListBucket"]
    resources = [local.state_arn]
  }
  statement {
    sid       = "EtatLecture"
    actions   = ["s3:GetObject"]
    resources = ["${local.state_arn}/env/*"]
  }
  statement {
    sid       = "EtatVerrouUniquement"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["${local.state_arn}/env/*.tflock"]
  }

  statement {
    sid = "MetadonneesDynamoDB"
    actions = [
      "dynamodb:DescribeTable", "dynamodb:DescribeContinuousBackups",
      "dynamodb:DescribeTimeToLive", "dynamodb:ListTagsOfResource",
    ]
    resources = ["${local.arn_base}:dynamodb:${var.region}:${local.account_id}:table/${local.app_prefix}-*"]
  }
  statement {
    sid       = "MetadonneesLambda"
    actions   = ["lambda:Get*", "lambda:List*"]
    resources = ["${local.arn_base}:lambda:${var.region}:${local.account_id}:function:${local.app_prefix}-*"]
  }
  statement {
    sid       = "MetadonneesIAM"
    actions   = ["iam:Get*", "iam:List*"]
    resources = ["${local.arn_base}:iam::${local.account_id}:role/${local.app_prefix}-*"]
  }
  statement {
    sid       = "MetadonneesKMS"
    actions   = ["kms:DescribeKey", "kms:GetKeyPolicy", "kms:GetKeyRotationStatus", "kms:ListResourceTags"]
    resources = ["${local.arn_base}:kms:${var.region}:${local.account_id}:key/*"]
  }
  statement {
    sid       = "ListeAliasKMS"
    actions   = ["kms:ListAliases"]
    resources = ["*"]
  }
  statement {
    sid       = "MetadonneesLogs"
    actions   = ["logs:DescribeLogGroups", "logs:ListTagsForResource", "logs:ListTagsLogGroup"]
    resources = ["${local.arn_base}:logs:${var.region}:${local.account_id}:log-group:*"]
  }
  statement {
    sid     = "MetadonneesApiGateway"
    actions = ["apigateway:GET"]
    resources = [
      "${local.arn_base}:apigateway:${var.region}::/apis",
      "${local.arn_base}:apigateway:${var.region}::/apis/*",
      "${local.arn_base}:apigateway:${var.region}::/tags/*",
    ]
  }
}

resource "aws_iam_role_policy" "plan" {
  name   = "lecture-seule-plan"
  role   = aws_iam_role.plan.id
  policy = data.aws_iam_policy_document.plan.json
}
