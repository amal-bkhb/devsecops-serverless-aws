resource "aws_apigatewayv2_api" "this" {
  name          = "${var.name_prefix}-api"
  protocol_type = "HTTP"
}

resource "aws_cloudwatch_log_group" "access" {
  #checkov:skip=CKV_AWS_158:Journaux d'accès sans donnée sensible, chiffrement par défaut de CloudWatch suffisant
  #checkov:skip=CKV_AWS_338:Rétention volontairement courte (<= 30 jours, règle OPA n° 5) pour limiter les coûts
  name              = "/aws/apigateway/${var.name_prefix}-api"
  retention_in_days = var.log_retention_days
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = "$default"
  auto_deploy = true

  # Limite les abus et protège la facture.
  default_route_settings {
    throttling_rate_limit  = var.throttling_rate_limit
    throttling_burst_limit = var.throttling_burst_limit
  }

  # Journal de chaque requête : traçabilité en cas d'incident.
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.access.arn
    format = jsonencode({
      requestId = "$context.requestId"
      sourceIp  = "$context.identity.sourceIp"
      caller    = "$context.identity.caller"
      routeKey  = "$context.routeKey"
      status    = "$context.status"
      time      = "$context.requestTime"
    })
  }
}

resource "aws_apigatewayv2_integration" "fn" {
  for_each               = var.invoke_arns
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = each.value
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "this" {
  for_each  = var.routes
  api_id    = aws_apigatewayv2_api.this.id
  route_key = each.key
  target    = "integrations/${aws_apigatewayv2_integration.fn[each.value].id}"

  # Seul un appelant avec des identifiants AWS valides ET la permission execute-api:Invoke est accepté.
  authorization_type = "AWS_IAM"
}

# Chaque fonction n'accepte d'être invoquée que par SA route de CETTE API.
resource "aws_lambda_permission" "api" {
  for_each      = var.routes
  statement_id  = "AllowApiGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.function_names[each.value]
  principal     = "apigateway.amazonaws.com"
  # Ex. ".../*/PUT/tasks/*" : les paramètres de chemin ({id}) sont remplacés par un joker.
  source_arn = "${aws_apigatewayv2_api.this.execution_arn}/*/${split(" ", each.key)[0]}${replace(split(" ", each.key)[1], "/\\{[^}]+\\}/", "*")}"
}
