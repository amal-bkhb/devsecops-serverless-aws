output "api_endpoint" {
  description = "URL de base de l'API."
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "execution_arn" {
  description = "ARN d'exécution, pour accorder execute-api:Invoke aux appelants autorisés."
  value       = aws_apigatewayv2_api.this.execution_arn
}
