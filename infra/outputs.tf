output "table_name" {
  value = module.dynamodb.table_name
}

output "table_arn" {
  value = module.dynamodb.table_arn
}

output "api_endpoint" {
  value = module.api.api_endpoint
}
