output "lambda_function_name" {
  description = "Name of the Lambda function that monitors Amazon Connect quotas."
  value       = module.connect_quota_monitor.lambda_function_name
}

output "lambda_function_arn" {
  description = "ARN of the monitoring Lambda function."
  value       = module.connect_quota_monitor.lambda_function_arn
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic that receives quota alerts."
  value       = module.connect_quota_monitor.sns_topic_arn
}

output "metrics_bucket_name" {
  description = "Name of the S3 bucket used for storing metrics, when enabled."
  value       = module.connect_quota_monitor.metrics_bucket_name
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table used for storing metrics, when enabled."
  value       = module.connect_quota_monitor.dynamodb_table_name
}

output "deployment_bucket_name" {
  description = "Name of the deployment bucket hosting Lambda artifacts when managed by Terraform."
  value       = module.connect_quota_monitor.deployment_bucket_name
}

output "dead_letter_queue_url" {
  description = "URL of the Lambda dead-letter queue."
  value       = module.connect_quota_monitor.dead_letter_queue_url
}
