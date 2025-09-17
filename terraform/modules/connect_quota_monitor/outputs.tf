output "lambda_function_name" {
  value       = aws_lambda_function.quota_monitor.function_name
  description = "Lambda function name."
}

output "lambda_function_arn" {
  value       = aws_lambda_function.quota_monitor.arn
  description = "Lambda function ARN."
}

output "sns_topic_arn" {
  value       = aws_sns_topic.alerts.arn
  description = "SNS topic ARN."
}

output "metrics_bucket_name" {
  value       = local.metrics_bucket_name
  description = "Metrics S3 bucket name when S3 storage is enabled."
}

output "dynamodb_table_name" {
  value       = var.use_dynamodb_storage ? var.dynamodb_table_name : ""
  description = "DynamoDB table name when enabled."
}

output "deployment_bucket_name" {
  value       = local.deployment_bucket_name
  description = "Deployment bucket name when managed by Terraform."
}

output "dead_letter_queue_url" {
  value       = aws_sqs_queue.lambda_dlq.id
  description = "Dead letter queue URL."
}
