module "dynamodb" {
  source     = "./modules/dynamodb"
  table_name = "${var.project}-${var.environment}-tasks"
}
