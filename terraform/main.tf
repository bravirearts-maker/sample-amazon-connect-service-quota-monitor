provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

module "connect_quota_monitor" {
  source = "./modules/connect_quota_monitor"

  stack_name              = var.stack_name
  threshold_percentage    = var.threshold_percentage
  lambda_timeout          = var.lambda_timeout
  lambda_memory           = var.lambda_memory
  lambda_runtime          = var.lambda_runtime
  schedule_expression     = var.schedule_expression
  notification_email      = var.notification_email
  use_s3_storage          = var.use_s3_storage
  s3_bucket_name          = var.s3_bucket_name
  use_dynamodb_storage    = var.use_dynamodb_storage
  dynamodb_table_name     = var.dynamodb_table_name
  sns_topic_name          = var.sns_topic_name
  create_deployment_bucket = var.create_deployment_bucket
  deployment_bucket_name  = var.deployment_bucket_name
  deployment_method       = var.deployment_method
  vpc_id                  = var.vpc_id
  subnet_ids              = var.subnet_ids

  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
}
