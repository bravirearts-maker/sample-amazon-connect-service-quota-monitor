locals {
  lambda_name                  = "${var.name_prefix}-EnhancedConnectQuotaMonitor"
  dlq_name                     = "${var.name_prefix}-ConnectQuotaMonitor-DLQ"
  enable_vpc                   = var.vpc_id != ""
  subnet_count                 = length(var.subnet_ids)
  metrics_bucket_arn           = var.metrics_bucket_name == "" ? "" : "arn:aws:s3:::${var.metrics_bucket_name}"
  metrics_objects_arn          = var.metrics_bucket_name == "" ? "" : "arn:aws:s3:::${var.metrics_bucket_name}/*"
  deployment_bucket_arn        = var.deployment_bucket_name == "" ? "" : "arn:aws:s3:::${var.deployment_bucket_name}"
  deployment_bucket_objects_arn = var.deployment_bucket_name == "" ? "" : "arn:aws:s3:::${var.deployment_bucket_name}/*"
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_kms_key" "lambda" {
  description             = "KMS key for Lambda environment variables encryption"
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
        Sid = "Allow Lambda service"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
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

resource "aws_kms_alias" "lambda" {
  name          = "alias/${var.name_prefix}-lambda-key"
  target_key_id = aws_kms_key.lambda.key_id
}

resource "aws_security_group" "lambda" {
  count       = local.enable_vpc ? 1 : 0
  name        = "${var.name_prefix}-Lambda-SG"
  description = "Security group for Connect Quota Monitor Lambda function"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS outbound for AWS API calls"
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-Lambda-SG"
  })
}

resource "aws_sqs_queue" "dlq" {
  name                      = local.dlq_name
  message_retention_seconds = 1209600
  kms_master_key_id         = "alias/aws/sqs"
  tags                      = merge(var.tags, { Purpose = "ConnectQuotaMonitorDLQ" })
}

resource "aws_iam_role" "lambda" {
  name               = "${var.name_prefix}-EnhancedLambdaRole"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  managed_policy_arns = compact([
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
    local.enable_vpc ? "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole" : null
  ])

  tags = var.tags
}

data "aws_iam_policy_document" "enhanced" {
  statement {
    sid     = "ConnectCorePermissions"
    actions = [
      "connect:ListInstances",
      "connect:ListUsers",
      "connect:ListQueues",
      "connect:ListPhoneNumbers",
      "connect:ListPhoneNumbersV2",
      "connect:ListHoursOfOperations",
      "connect:ListContactFlows",
      "connect:ListContactFlowModules",
      "connect:ListRoutingProfiles",
      "connect:ListSecurityProfiles",
      "connect:ListQuickConnects",
      "connect:ListAgentStatuses",
      "connect:ListPrompts",
      "connect:ListTaskTemplates",
      "connect:ListEvaluationForms",
      "connect:ListLambdaFunctions",
      "connect:ListBots",
      "connect:ListIntegrationAssociations",
      "connect:ListPredefinedAttributes",
      "connect:DescribeUserHierarchyStructure"
    ]
    resources = ["*"]
    effect    = "Allow"
  }

  statement {
    sid       = "DirectoryServicePermissions"
    actions   = ["ds:DescribeDirectories"]
    resources = ["*"]
    effect    = "Allow"
  }

  statement {
    sid       = "ConnectCasesPermissions"
    actions   = [
      "cases:ListDomains",
      "cases:ListFields",
      "cases:ListTemplates",
      "cases:ListLayouts"
    ]
    resources = ["*"]
    effect    = "Allow"
  }

  statement {
    sid       = "CustomerProfilesPermissions"
    actions   = [
      "profile:ListDomains",
      "profile:ListProfileObjectTypes",
      "profile:ListIntegrations"
    ]
    resources = ["*"]
    effect    = "Allow"
  }

  statement {
    sid       = "VoiceIDPermissions"
    actions   = [
      "voiceid:ListDomains",
      "voiceid:ListSpeakers",
      "voiceid:ListFraudsters",
      "voiceid:ListWatchlists"
    ]
    resources = ["*"]
    effect    = "Allow"
  }

  statement {
    sid       = "WisdomPermissions"
    actions   = [
      "wisdom:ListKnowledgeBases",
      "wisdom:ListContents",
      "wisdom:ListAssistants"
    ]
    resources = ["*"]
    effect    = "Allow"
  }

  statement {
    sid       = "ConnectCampaignsPermissions"
    actions   = [
      "connect-campaigns:ListCampaigns",
      "connect-campaigns:DescribeCampaign"
    ]
    resources = ["*"]
    effect    = "Allow"
  }

  statement {
    sid       = "AppIntegrationsPermissions"
    actions   = [
      "appintegrations:ListApplications",
      "appintegrations:ListDataIntegrations",
      "appintegrations:ListEventIntegrations"
    ]
    resources = ["*"]
    effect    = "Allow"
  }

  statement {
    sid       = "ServiceQuotasPermissions"
    actions   = [
      "servicequotas:ListServiceQuotas",
      "servicequotas:GetServiceQuota",
      "servicequotas:ListServices"
    ]
    resources = ["*"]
    effect    = "Allow"
  }

  statement {
    sid       = "CloudWatchPermissions"
    actions   = [
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:ListMetrics",
      "cloudwatch:GetMetricData"
    ]
    resources = ["*"]
    effect    = "Allow"
  }

  statement {
    sid       = "STSPermissions"
    actions   = ["sts:GetCallerIdentity"]
    resources = ["*"]
    effect    = "Allow"
  }

  statement {
    sid       = "SNSPermissions"
    actions   = [
      "sns:Publish",
      "sns:GetTopicAttributes",
      "sns:ListSubscriptionsByTopic"
    ]
    resources = [var.sns_topic_arn]
    effect    = "Allow"
  }

  statement {
    sid       = "SNSListPermissions"
    actions   = ["sns:ListTopics"]
    resources = ["*"]
    effect    = "Allow"
  }

  statement {
    sid       = "SQSPermissions"
    actions   = [
      "sqs:SendMessage",
      "sqs:GetQueueAttributes"
    ]
    resources = [aws_sqs_queue.dlq.arn]
    effect    = "Allow"
  }

  statement {
    sid       = "KMSPermissions"
    actions   = [
      "kms:Decrypt",
      "kms:GenerateDataKey",
      "kms:DescribeKey"
    ]
    resources = compact([
      aws_kms_key.lambda.arn,
      var.sns_kms_key_arn,
      var.use_dynamodb_storage && var.dynamodb_kms_key_arn != "" ? var.dynamodb_kms_key_arn : null
    ])
    effect = "Allow"
  }
}

resource "aws_iam_role_policy" "enhanced" {
  name   = "EnhancedConnectQuotaMonitorPolicy"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.enhanced.json
}

resource "aws_iam_policy" "s3_storage" {
  count = var.use_s3_storage && var.metrics_bucket_name != "" ? 1 : 0
  name  = "${var.name_prefix}-S3StoragePolicy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:GetObject", "s3:ListBucket"]
        Resource = [
          local.metrics_bucket_arn,
          local.metrics_objects_arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "s3" {
  count      = var.use_s3_storage && var.metrics_bucket_name != "" ? 1 : 0
  role       = aws_iam_role.lambda.name
  policy_arn = aws_iam_policy.s3_storage[0].arn
}

resource "aws_iam_policy" "dynamodb_storage" {
  count = var.use_dynamodb_storage && var.dynamodb_table_arn != "" ? 1 : 0
  name  = "${var.name_prefix}-DynamoDBStoragePolicy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:CreateTable",
          "dynamodb:DescribeTable"
        ]
        Resource = [
          var.dynamodb_table_arn,
          "${var.dynamodb_table_arn}/index/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "dynamodb" {
  count      = var.use_dynamodb_storage && var.dynamodb_table_arn != "" ? 1 : 0
  role       = aws_iam_role.lambda.name
  policy_arn = aws_iam_policy.dynamodb_storage[0].arn
}

data "archive_file" "lambda" {
  count       = var.deployment_method == "s3" ? 0 : 1
  type        = "zip"
  source_file = var.lambda_source_path
  output_path = "${path.module}/lambda-deployment.zip"
}

resource "aws_lambda_function" "this" {
  function_name = local.lambda_name
  handler       = "lambda_function.main"
  role          = aws_iam_role.lambda.arn
  runtime       = var.lambda_runtime
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory
  kms_key_arn   = aws_kms_key.lambda.arn
  reserved_concurrent_executions = 5

  dynamic "vpc_config" {
    for_each = local.enable_vpc ? [1] : []
    content {
      security_group_ids = [aws_security_group.lambda[0].id]
      subnet_ids         = var.subnet_ids
    }
  }

  environment {
    variables = {
      ALERT_SNS_TOPIC_ARN = var.sns_topic_arn
      THRESHOLD_PERCENTAGE = tostring(var.threshold_percentage)
      S3_BUCKET            = var.metrics_bucket_name
      USE_S3_STORAGE       = tostring(var.use_s3_storage)
      USE_DYNAMODB         = tostring(var.use_dynamodb_storage)
      DYNAMODB_TABLE       = var.dynamodb_table_name
      DEPLOYMENT_METHOD    = var.deployment_method
      DEPLOYMENT_BUCKET    = var.deployment_bucket_name
    }
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.dlq.arn
  }

  filename         = var.deployment_method == "s3" ? null : data.archive_file.lambda[0].output_path
  source_code_hash = var.deployment_method == "s3" ? null : data.archive_file.lambda[0].output_base64sha256
  s3_bucket        = var.deployment_method == "s3" ? var.deployment_bucket_name : null
  s3_key           = var.deployment_method == "s3" ? var.deployment_package_key : null

  tags = merge(var.tags, {
    Purpose = "EnhancedConnectQuotaMonitor",
    Version = "2.0"
  })

  lifecycle {
    precondition {
      condition     = !(local.enable_vpc) || local.subnet_count > 0
      error_message = "subnet_ids must be provided when vpc_id is specified."
    }

    precondition {
      condition     = var.deployment_method != "s3" || var.deployment_bucket_name != ""
      error_message = "deployment_bucket_name must be provided when deployment_method is 's3'."
    }
  }
}

resource "aws_cloudwatch_event_rule" "schedule" {
  name                = "${var.name_prefix}-Schedule"
  description         = "Scheduled rule to trigger Connect Quota Monitor Lambda"
  schedule_expression = var.schedule_expression
  is_enabled          = true

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule      = aws_cloudwatch_event_rule.schedule.name
  arn       = aws_lambda_function.this.arn
  target_id = "ConnectQuotaMonitorTarget"
}

resource "aws_lambda_permission" "allow_events" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.arn
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.schedule.arn
}

