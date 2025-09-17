output "sns_topic_arn" {
  description = "ARN of the SNS topic"
  value       = aws_sns_topic.alerts.arn
}

output "kms_key_arn" {
  description = "ARN of the SNS KMS key"
  value       = aws_kms_key.sns.arn
}

