provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  tags = merge({
    Purpose   = "ConnectQuotaMonitor",
    ManagedBy = "Terraform"
  }, var.tags)
}

module "notifications" {
  source             = "./modules/notifications"
  name_prefix        = var.name_prefix
  sns_topic_name     = var.sns_topic_name
  notification_email = var.notification_email
  tags               = local.tags
}

module "storage" {
  source                     = "./modules/storage"
  name_prefix                = var.name_prefix
  enable_s3_storage          = var.use_s3_storage
  metrics_bucket_name        = var.s3_bucket_name
  enable_deployment_bucket   = var.create_deployment_bucket
  deployment_bucket_name     = var.deployment_bucket_name
  tags                       = local.tags
}

module "dynamodb" {
  source                  = "./modules/dynamodb"
  enable_dynamodb_storage = var.use_dynamodb_storage
  table_name              = var.dynamodb_table_name
  name_prefix             = var.name_prefix
  tags                    = local.tags
}

module "lambda" {
  source                    = "./modules/lambda"
  name_prefix               = var.name_prefix
  lambda_runtime            = var.lambda_runtime
  lambda_timeout            = var.lambda_timeout
  lambda_memory             = var.lambda_memory
  threshold_percentage      = var.threshold_percentage
  schedule_expression       = var.schedule_expression
  sns_topic_arn             = module.notifications.sns_topic_arn
  sns_kms_key_arn           = module.notifications.kms_key_arn
  use_s3_storage            = var.use_s3_storage
  metrics_bucket_name       = module.storage.metrics_bucket_name
  use_dynamodb_storage      = var.use_dynamodb_storage
  dynamodb_table_name       = module.dynamodb.table_name
  dynamodb_table_arn        = module.dynamodb.table_arn
  dynamodb_kms_key_arn      = module.dynamodb.kms_key_arn
  deployment_method         = var.deployment_method
  deployment_bucket_name    = module.storage.deployment_bucket_name
  deployment_package_key    = "lambda-deployment.zip"
  lambda_source_path        = "${path.root}/../lambda_function.py"
  vpc_id                    = var.vpc_id
  subnet_ids                = var.subnet_ids
  tags                      = local.tags
}

