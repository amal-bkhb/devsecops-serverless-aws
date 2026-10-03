locals {
  name_prefix = "${var.project}-${var.environment}"

  # Matrice IAM (docs/iam-matrix.md) : chaque Lambda => son unique action DynamoDB.
  functions = {
    get_tasks   = "dynamodb:Scan"
    create_task = "dynamodb:PutItem"
    update_task = "dynamodb:UpdateItem"
    delete_task = "dynamodb:DeleteItem"
  }
}

module "dynamodb" {
  source     = "./modules/dynamodb"
  table_name = "${local.name_prefix}-tasks"
}

module "iam" {
  source      = "./modules/iam"
  name_prefix = local.name_prefix
  region      = var.region
  table_arn   = module.dynamodb.table_arn
  kms_key_arn = module.dynamodb.kms_key_arn
  functions   = local.functions
}

module "lambda" {
  source       = "./modules/lambda"
  name_prefix  = local.name_prefix
  role_arns    = module.iam.role_arns
  package_path = "${path.root}/../build/lambda.zip"
  table_name   = module.dynamodb.table_name
}

module "api" {
  source      = "./modules/api"
  name_prefix = local.name_prefix
  routes = {
    "GET /tasks"         = "get_tasks"
    "POST /tasks"        = "create_task"
    "PUT /tasks/{id}"    = "update_task"
    "DELETE /tasks/{id}" = "delete_task"
  }
  invoke_arns    = module.lambda.invoke_arns
  function_names = module.lambda.function_names
}
