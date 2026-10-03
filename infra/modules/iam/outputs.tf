output "role_arns" {
  description = "ARN du rôle de chaque Lambda, utilisé par le module lambda."
  value       = { for name, role in aws_iam_role.lambda : name => role.arn }
}
