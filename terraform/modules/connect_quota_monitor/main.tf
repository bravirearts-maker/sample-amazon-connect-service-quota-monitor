locals {
  sanitized_stack_name   = replace(lower(var.stack_name), "[^a-z0-9-]", "-")
  create_metrics_bucket  = var.use_s3_storage && var.s3_bucket_name == ""
  create_logs_bucket     = local.create_metrics_bucket
  metrics_bucket_name    = var.use_s3_storage ? (local.create_metrics_bucket ? aws_s3_bucket.metrics[0].bucket : var.s3_bucket_name) : ""
  create_deployment_bucket = var.create_deployment_bucket
  deployment_bucket_name = local.create_deployment_bucket ? (var.deployment_bucket_name != "" ? var.deployment_bucket_name : format("%s-deploy-%s-%s", local.sanitized_stack_name, var.account_id, var.region)) : var.deployment_bucket_name
  use_s3_deployment      = var.deployment_method == "s3"
  use_vpc                = var.vpc_id != ""
}

resource "aws_kms_key" "sns" {
  description             = "KMS key for SNS topic encryption - Connect Quota Monitor"
  deletion_window_in_days = 7
}

resource "aws_kms_alias" "sns" {
  name          = "alias/${var.stack_name}-sns-key"
  target_key_id = aws_kms_key.sns.key_id
}

resource "aws_sns_topic" "alerts" {
  name              = var.sns_topic_name
  display_name      = "Connect Quota Alerts"
  kms_master_key_id = aws_kms_key.sns.arn

  tags = {
    Purpose   = "ConnectQuotaMonitor"
    ManagedBy = "Terraform"
  }
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.notification_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

resource "aws_s3_bucket" "logs" {
  count = local.create_logs_bucket ? 1 : 0

  tags = {
    Purpose   = "ConnectQuotaMonitorAccessLogs"
    ManagedBy = "Terraform"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  count  = local.create_logs_bucket ? 1 : 0
  bucket = aws_s3_bucket.logs[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  count                   = local.create_logs_bucket ? 1 : 0
  bucket                  = aws_s3_bucket.logs[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket" "metrics" {
  count = local.create_metrics_bucket ? 1 : 0

  logging {
    target_bucket = aws_s3_bucket.logs[0].bucket
    target_prefix = "access-logs/"
  }

  lifecycle_rule {
    id      = "ExpireOldReports"
    enabled = true

    filter {
      prefix = "connect-reports/"
    }

    expiration {
      days = 365
    }
  }

  lifecycle_rule {
    id      = "ExpireOldMetrics"
    enabled = true

    filter {
      prefix = "connect-metrics/"
    }

    expiration {
      days = 365
    }
  }

  tags = {
    Purpose   = "ConnectQuotaMonitor"
    ManagedBy = "Terraform"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "metrics" {
  count  = local.create_metrics_bucket ? 1 : 0
  bucket = aws_s3_bucket.metrics[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "metrics" {
  count                   = local.create_metrics_bucket ? 1 : 0
  bucket                  = aws_s3_bucket.metrics[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_kms_key" "dynamodb" {
  count                   = var.use_dynamodb_storage ? 1 : 0
  description             = "KMS key for DynamoDB table encryption"
  deletion_window_in_days = 7
}

resource "aws_kms_alias" "dynamodb" {
  count        = var.use_dynamodb_storage ? 1 : 0
  name         = "alias/${var.stack_name}-dynamodb-key"
  target_key_id = aws_kms_key.dynamodb[0].key_id
}

resource "aws_dynamodb_table" "metrics" {
  count          = var.use_dynamodb_storage ? 1 : 0
  name           = var.dynamodb_table_name
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5

  hash_key  = "id"
  range_key = "timestamp"

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

  global_secondary_index {
    name            = "InstanceIdIndex"
    hash_key        = "instance_id"
    range_key       = "timestamp"
    projection_type = "ALL"
    read_capacity   = 5
    write_capacity  = 5
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.dynamodb[0].arn
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Purpose   = "ConnectQuotaMonitor"
    ManagedBy = "Terraform"
  }
}

resource "aws_kms_key" "lambda" {
  description             = "KMS key for Lambda environment variables encryption"
  deletion_window_in_days = 7
}

resource "aws_kms_alias" "lambda" {
  name          = "alias/${var.stack_name}-lambda-key"
  target_key_id = aws_kms_key.lambda.key_id
}

resource "aws_security_group" "lambda" {
  count       = local.use_vpc ? 1 : 0
  name        = "${var.stack_name}-Lambda-SG"
  description = "Security group for Connect Quota Monitor Lambda function"
  vpc_id      = var.vpc_id

  egress {
    description = "HTTPS outbound for AWS API calls"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name     = "${var.stack_name}-Lambda-SG"
    Purpose  = "ConnectQuotaMonitor"
    ManagedBy = "Terraform"
  }
}

resource "aws_sqs_queue" "lambda_dlq" {
  name                      = "${var.stack_name}-ConnectQuotaMonitor-DLQ"
  message_retention_seconds = 1209600
  kms_master_key_id         = "alias/aws/sqs"

  tags = {
    Purpose   = "ConnectQuotaMonitorDLQ"
    ManagedBy = "Terraform"
  }
}

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/../../../lambda_function.py"
  output_path = "${path.module}/../../build/lambda.zip"
}

resource "aws_s3_bucket" "deployment" {
  count  = local.create_deployment_bucket ? 1 : 0
  bucket = local.deployment_bucket_name

  lifecycle_rule {
    id      = "DeleteOldDeploymentPackages"
    enabled = true

    expiration {
      days = 30
    }

    noncurrent_version_expiration {
      days = 7
    }
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  versioning {
    enabled = true
  }

  tags = {
    Purpose   = "ConnectQuotaMonitorDeployment"
    ManagedBy = "Terraform"
  }
}

resource "aws_s3_bucket_public_access_block" "deployment" {
  count                   = local.create_deployment_bucket ? 1 : 0
  bucket                  = aws_s3_bucket.deployment[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "lambda_package" {
  count = local.use_s3_deployment ? 1 : 0

  bucket = local.create_deployment_bucket ? aws_s3_bucket.deployment[0].bucket : local.deployment_bucket_name
  key    = "lambda-deployment.zip"
  source = data.archive_file.lambda.output_path
  etag   = filemd5(data.archive_file.lambda.output_path)
}

locals {
  lambda_environment = {
    ALERT_SNS_TOPIC_ARN = aws_sns_topic.alerts.arn
    THRESHOLD_PERCENTAGE = tostring(var.threshold_percentage)
    USE_S3_STORAGE       = tostring(var.use_s3_storage)
    S3_BUCKET            = local.metrics_bucket_name
    USE_DYNAMODB         = tostring(var.use_dynamodb_storage)
    DYNAMODB_TABLE       = var.dynamodb_table_name
    DEPLOYMENT_METHOD    = var.deployment_method
    DEPLOYMENT_BUCKET    = local.create_deployment_bucket ? local.deployment_bucket_name : coalesce(local.deployment_bucket_name, "")
  }
}

resource "aws_lambda_function" "quota_monitor" {
  function_name                  = "${var.stack_name}-EnhancedConnectQuotaMonitor"
  role                           = aws_iam_role.lambda.arn
  handler                        = "lambda_function.main"
  runtime                        = var.lambda_runtime
  timeout                        = var.lambda_timeout
  memory_size                    = var.lambda_memory
  reserved_concurrent_executions = 5
  kms_key_arn                    = aws_kms_key.lambda.arn
  filename                       = local.use_s3_deployment ? null : data.archive_file.lambda.output_path
  s3_bucket                      = local.use_s3_deployment ? (local.create_deployment_bucket ? aws_s3_bucket.deployment[0].bucket : local.deployment_bucket_name) : null
  s3_key                         = local.use_s3_deployment ? aws_s3_object.lambda_package[0].key : null
  source_code_hash               = data.archive_file.lambda.output_base64sha256

  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }

  dynamic "vpc_config" {
    for_each = local.use_vpc ? [1] : []
    content {
      subnet_ids         = var.subnet_ids
      security_group_ids = [aws_security_group.lambda[0].id]
    }
  }

  environment {
    variables = local.lambda_environment
  }

  tags = {
    Purpose   = "EnhancedConnectQuotaMonitor"
    Version   = "2.0"
    ManagedBy = "Terraform"
  }

  lifecycle {
    precondition {
      condition     = !(local.use_s3_deployment && local.deployment_bucket_name == "")
      error_message = "deployment_method 's3' requires a deployment bucket name."
    }
    precondition {
      condition     = !(local.use_vpc && length(var.subnet_ids) == 0)
      error_message = "At least one subnet must be supplied when vpc_id is provided."
    }
  }
}

resource "aws_cloudwatch_event_rule" "schedule" {
  name                = "${var.stack_name}-Schedule"
  description         = "Scheduled rule to trigger Connect Quota Monitor Lambda"
  schedule_expression = var.schedule_expression
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule      = aws_cloudwatch_event_rule.schedule.name
  target_id = "ConnectQuotaMonitorTarget"
  arn       = aws_lambda_function.quota_monitor.arn
}

resource "aws_lambda_permission" "allow_events" {
  statement_id  = "AllowExecutionFromCloudWatchEvents"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.quota_monitor.arn
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.schedule.arn
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "lambda_permissions" {
  statement {
    sid    = "ConnectCorePermissions"
    effect = "Allow"
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
  }

  statement {
    sid    = "DirectoryServicePermissions"
    effect = "Allow"
    actions = ["ds:DescribeDirectories"]
    resources = ["*"]
  }

  statement {
    sid    = "ConnectCasesPermissions"
    effect = "Allow"
    actions = [
      "cases:ListDomains",
      "cases:ListFields",
      "cases:ListTemplates",
      "cases:ListLayouts"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "CustomerProfilesPermissions"
    effect = "Allow"
    actions = [
      "profile:ListDomains",
      "profile:ListProfileObjectTypes",
      "profile:ListIntegrations"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "VoiceIDPermissions"
    effect = "Allow"
    actions = [
      "voiceid:ListDomains",
      "voiceid:ListSpeakers",
      "voiceid:ListFraudsters",
      "voiceid:ListWatchlists"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "WisdomPermissions"
    effect = "Allow"
    actions = [
      "wisdom:ListKnowledgeBases",
      "wisdom:ListContents",
      "wisdom:ListAssistants"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ConnectCampaignsPermissions"
    effect = "Allow"
    actions = [
      "connect-campaigns:ListCampaigns",
      "connect-campaigns:DescribeCampaign"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AppIntegrationsPermissions"
    effect = "Allow"
    actions = [
      "appintegrations:ListApplications",
      "appintegrations:ListDataIntegrations",
      "appintegrations:ListEventIntegrations"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ServiceQuotasPermissions"
    effect = "Allow"
    actions = [
      "servicequotas:ListServiceQuotas",
      "servicequotas:GetServiceQuota",
      "servicequotas:ListServices"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "CloudWatchPermissions"
    effect = "Allow"
    actions = [
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:ListMetrics",
      "cloudwatch:GetMetricData"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "STSPermissions"
    effect = "Allow"
    actions   = ["sts:GetCallerIdentity"]
    resources = ["*"]
  }

  statement {
    sid    = "SNSPermissions"
    effect = "Allow"
    actions = [
      "sns:Publish",
      "sns:GetTopicAttributes",
      "sns:ListSubscriptionsByTopic"
    ]
    resources = [aws_sns_topic.alerts.arn]
  }

  statement {
    sid      = "SNSListPermissions"
    effect   = "Allow"
    actions  = ["sns:ListTopics"]
    resources = ["*"]
  }

  statement {
    sid    = "SQSPermissions"
    effect = "Allow"
    actions = [
      "sqs:SendMessage",
      "sqs:GetQueueAttributes"
    ]
    resources = [aws_sqs_queue.lambda_dlq.arn]
  }

  statement {
    sid    = "KMSPermissions"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey",
      "kms:DescribeKey"
    ]
    resources = [
      aws_kms_key.lambda.arn,
      aws_kms_key.sns.arn
    ]
  }

  dynamic "statement" {
    for_each = var.use_dynamodb_storage ? [1] : []
    content {
      sid    = "DynamoDBKMSPermissions"
      effect = "Allow"
      actions = [
        "kms:Decrypt",
        "kms:GenerateDataKey",
        "kms:DescribeKey"
      ]
      resources = [aws_kms_key.dynamodb[0].arn]
    }
  }
}

data "aws_iam_policy_document" "lambda_s3_policy" {
  count = var.use_s3_storage ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = local.create_metrics_bucket ? [
      aws_s3_bucket.metrics[0].arn,
      "${aws_s3_bucket.metrics[0].arn}/*"
    ] : [
      "arn:aws:s3:::${var.s3_bucket_name}",
      "arn:aws:s3:::${var.s3_bucket_name}/*"
    ]
  }
}

data "aws_iam_policy_document" "lambda_dynamodb_policy" {
  count = var.use_dynamodb_storage ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
      "dynamodb:PutItem",
      "dynamodb:GetItem",
      "dynamodb:Query",
      "dynamodb:Scan",
      "dynamodb:CreateTable",
      "dynamodb:DescribeTable"
    ]
    resources = [
      "arn:aws:dynamodb:${var.region}:${var.account_id}:table/${var.dynamodb_table_name}",
      "arn:aws:dynamodb:${var.region}:${var.account_id}:table/${var.dynamodb_table_name}/index/*"
    ]
  }
}

data "aws_iam_policy_document" "lambda_deployment_policy" {
  count = local.use_s3_deployment ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = [
      "arn:aws:s3:::${local.deployment_bucket_name}",
      "arn:aws:s3:::${local.deployment_bucket_name}/*"
    ]
  }
}

locals {
  inline_policies = concat(
    [
      {
        name   = "EnhancedConnectQuotaMonitorPolicy"
        policy = data.aws_iam_policy_document.lambda_permissions.json
      }
    ],
    var.use_s3_storage ? [
      {
        name   = "S3StoragePolicy"
        policy = data.aws_iam_policy_document.lambda_s3_policy[0].json
      }
    ] : [],
    var.use_dynamodb_storage ? [
      {
        name   = "DynamoDBStoragePolicy"
        policy = data.aws_iam_policy_document.lambda_dynamodb_policy[0].json
      }
    ] : [],
    local.use_s3_deployment ? [
      {
        name   = "DeploymentBucketPolicy"
        policy = data.aws_iam_policy_document.lambda_deployment_policy[0].json
      }
    ] : []
  )
}

resource "aws_iam_role" "lambda" {
  name               = "${var.stack_name}-EnhancedLambdaRole"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json

  managed_policy_arns = compact([
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
    local.use_vpc ? "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole" : ""
  ])

  dynamic "inline_policy" {
    for_each = local.inline_policies
    content {
      name   = inline_policy.value.name
      policy = inline_policy.value.policy
    }
  }
}
