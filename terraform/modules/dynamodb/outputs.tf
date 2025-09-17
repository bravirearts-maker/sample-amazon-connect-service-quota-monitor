output "table_name" {
  description = "Name of the DynamoDB table"
  value       = var.enable_dynamodb_storage ? aws_dynamodb_table.metrics[0].name : var.table_name
}

output "table_arn" {
  description = "ARN of the DynamoDB table"
  value       = var.enable_dynamodb_storage ? aws_dynamodb_table.metrics[0].arn : ""
}

output "kms_key_arn" {
  description = "ARN of the DynamoDB KMS key"
  value       = var.enable_dynamodb_storage ? aws_kms_key.dynamodb[0].arn : ""
}
