output "function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.this.function_name
}

output "function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.this.arn
}

output "dead_letter_queue_url" {
  description = "URL of the dead letter queue"
  value       = aws_sqs_queue.dlq.id
}

