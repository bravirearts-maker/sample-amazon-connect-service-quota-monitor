variable "name_prefix" {
  description = "Prefix used when naming Lambda resources"
  type        = string
}

variable "lambda_runtime" {
  description = "Runtime for the Lambda function"
  type        = string
}

variable "lambda_timeout" {
  description = "Timeout for the Lambda function"
  type        = number
}

variable "lambda_memory" {
  description = "Memory size for the Lambda function"
  type        = number
}

variable "threshold_percentage" {
  description = "Threshold percentage used by the Lambda function"
  type        = number
}

variable "schedule_expression" {
  description = "Schedule for triggering the Lambda function"
  type        = string
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for publishing alerts"
  type        = string
}

variable "sns_kms_key_arn" {
  description = "KMS key ARN used by the SNS topic"
  type        = string
}

variable "use_s3_storage" {
  description = "Whether Lambda should use S3 storage"
  type        = bool
}

variable "metrics_bucket_name" {
  description = "Name of the metrics S3 bucket"
  type        = string
  default     = ""
}

variable "use_dynamodb_storage" {
  description = "Whether Lambda should use DynamoDB storage"
  type        = bool
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  type        = string
  default     = ""
}

variable "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table"
  type        = string
  default     = ""
}

variable "dynamodb_kms_key_arn" {
  description = "ARN of the DynamoDB KMS key"
  type        = string
  default     = ""
}

variable "deployment_method" {
  description = "Deployment method for the Lambda function"
  type        = string
}

variable "deployment_bucket_name" {
  description = "S3 bucket name where deployment packages are stored"
  type        = string
  default     = ""
}

variable "deployment_package_key" {
  description = "Object key for the Lambda deployment package"
  type        = string
  default     = "lambda-deployment.zip"
}

variable "lambda_source_path" {
  description = "Path to the local Lambda source file"
  type        = string
}

variable "vpc_id" {
  description = "Optional VPC ID for the Lambda function"
  type        = string
  default     = ""
}

variable "subnet_ids" {
  description = "Optional subnet IDs for the Lambda function"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags applied to Lambda resources"
  type        = map(string)
  default     = {}
}
