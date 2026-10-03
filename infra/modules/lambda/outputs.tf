output "invoke_arns" {
  description = "ARN d'invocation de chaque fonction, utilisé par API Gateway."
  value       = { for name, fn in aws_lambda_function.fn : name => fn.invoke_arn }
}

output "function_names" {
  value = { for name, fn in aws_lambda_function.fn : name => fn.function_name }
}
