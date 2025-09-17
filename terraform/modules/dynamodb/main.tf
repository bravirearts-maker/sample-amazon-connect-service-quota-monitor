resource "aws_kms_key" "dynamodb" {
  count                   = var.enable_dynamodb_storage ? 1 : 0
  description             = "KMS key for DynamoDB table encryption"
  deletion_window_in_days = 30

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "Enable IAM User Permissions"
        Effect   = "Allow"
        Principal = {
          AWS = "*"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid = "Allow DynamoDB service"
        Effect = "Allow"
        Principal = {
          Service = "dynamodb.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

resource "aws_kms_alias" "dynamodb" {
  count         = var.enable_dynamodb_storage ? 1 : 0
  name          = "alias/${var.name_prefix}-dynamodb-key"
  target_key_id = aws_kms_key.dynamodb[0].key_id
}

resource "aws_dynamodb_table" "metrics" {
  count          = var.enable_dynamodb_storage ? 1 : 0
  name           = var.table_name
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  attribute {
    name = "instance_id"
    type = "S"
  }

  hash_key  = "id"
  range_key = "timestamp"

  global_secondary_index {
    name               = "InstanceIdIndex"
    hash_key           = "instance_id"
    range_key          = "timestamp"
    projection_type    = "ALL"
    read_capacity      = 5
    write_capacity     = 5
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.dynamodb[0].arn
  }

  tags = var.tags
}

