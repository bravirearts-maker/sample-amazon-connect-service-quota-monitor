output "lambda_function_name" {
  description = "Name of the deployed Lambda function"
  value       = module.lambda.function_name
}

output "lambda_function_arn" {
  description = "ARN of the deployed Lambda function"
  value       = module.lambda.function_arn
}

output "sns_topic_arn" {
  description = "SNS topic ARN for quota alerts"
  value       = module.notifications.sns_topic_arn
}

output "metrics_bucket_name" {
  description = "S3 bucket name used for metrics storage"
  value       = module.storage.metrics_bucket_name
}

output "dynamodb_table_name" {
  description = "DynamoDB table name used for metrics storage"
  value       = module.dynamodb.table_name
}

output "deployment_bucket_name" {
  description = "S3 bucket name used for Lambda deployment packages"
  value       = module.storage.deployment_bucket_name
}

output "dead_letter_queue_url" {
  description = "URL of the Lambda dead letter queue"
  value       = module.lambda.dead_letter_queue_url
}

