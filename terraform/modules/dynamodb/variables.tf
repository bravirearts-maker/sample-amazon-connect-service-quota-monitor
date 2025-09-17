variable "enable_dynamodb_storage" {
  description = "Whether to provision the DynamoDB table"
  type        = bool
}

variable "table_name" {
  description = "Name of the DynamoDB table"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for DynamoDB-related resources"
  type        = string
}

variable "tags" {
  description = "Tags applied to DynamoDB resources"
  type        = map(string)
  default     = {}
}
