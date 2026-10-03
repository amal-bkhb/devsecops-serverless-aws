output "table_name" {
  value = aws_dynamodb_table.tasks.name
}

output "table_arn" {
  description = "ARN exact de la table, utilisé par les politiques IAM des Lambda."
  value       = aws_dynamodb_table.tasks.arn
}

output "kms_key_arn" {
  value = aws_kms_key.table.arn
}
