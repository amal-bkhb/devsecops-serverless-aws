# Log group créé AVANT la fonction, avec une rétention définie.
# Le rôle n'a pas logs:CreateLogGroup : sans cette ressource, la fonction ne pourrait pas journaliser.
resource "aws_cloudwatch_log_group" "fn" {
  #checkov:skip=CKV_AWS_158:Journaux sans donnée sensible (erreurs génériques), chiffrement par défaut de CloudWatch suffisant
  #checkov:skip=CKV_AWS_338:Rétention volontairement courte (<= 30 jours, règle OPA n° 5) pour limiter les coûts
  for_each          = var.role_arns
  name              = "/aws/lambda/${var.name_prefix}-${each.key}"
  retention_in_days = var.log_retention_days
}

resource "aws_lambda_function" "fn" {
  #checkov:skip=CKV_AWS_117:Pas de VPC : sans NAT Gateway, il faudrait des endpoints payants ; seul DynamoDB est appelé, via IAM
  #checkov:skip=CKV_AWS_116:Pas de DLQ : invocation synchrone par API Gateway, l'erreur est renvoyée au client
  #checkov:skip=CKV_AWS_115:Pas de concurrence réservée : quota trop bas sur un compte neuf ; throttling assuré par API Gateway
  #checkov:skip=CKV_AWS_50:Pas de X-Ray : il exige une permission sur Resource "*", contraire à la règle OPA n° 3
  #checkov:skip=CKV_AWS_173:Variables d'environnement non sensibles (nom de table uniquement)
  #checkov:skip=CKV_AWS_272:Signature de code hors périmètre ; intégrité assurée par le pipeline (seul main déploie)
  for_each = var.role_arns

  function_name    = "${var.name_prefix}-${each.key}"
  role             = each.value
  runtime          = "python3.12"
  architectures    = ["x86_64"] # doit correspondre à la plateforme du paquet (manylinux2014_x86_64)
  handler          = "app.handlers.${each.key}.handler"
  filename         = var.package_path
  source_code_hash = filebase64sha256(var.package_path) # redéploie dès que le code change
  memory_size      = 128
  timeout          = 10

  environment {
    variables = {
      TABLE_NAME = var.table_name
      LOG_LEVEL  = "INFO"
    }
  }

  depends_on = [aws_cloudwatch_log_group.fn]
}
