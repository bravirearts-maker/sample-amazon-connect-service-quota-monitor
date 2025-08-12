#!/bin/bash
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

# Complete deployment script for Amazon Connect Service Quota Monitor
# This script deploys the CloudFormation stack and updates the Lambda function code

set -e

# Configuration
STACK_NAME="ConnectQuotaMonitor"
TEMPLATE_FILE="connect-quota-monitor-cfn.yaml"
PYTHON_SCRIPT="lambda_function.py"

# Default parameters (can be overridden via environment variables)
THRESHOLD_PERCENTAGE=${THRESHOLD_PERCENTAGE:-80}
NOTIFICATION_EMAIL=${NOTIFICATION_EMAIL:-""}
VPC_ID=${VPC_ID:-""}
SUBNET_IDS=${SUBNET_IDS:-""}
SCHEDULE_EXPRESSION=${SCHEDULE_EXPRESSION:-"rate(1 hour)"}

echo "=== Amazon Connect Service Quota Monitor Deployment ==="
echo "Stack Name: $STACK_NAME"
echo "Template: $TEMPLATE_FILE"
echo "Threshold: $THRESHOLD_PERCENTAGE%"
echo "Schedule: $SCHEDULE_EXPRESSION"

if [ ! -z "$NOTIFICATION_EMAIL" ]; then
    echo "Email: $NOTIFICATION_EMAIL"
fi

if [ ! -z "$VPC_ID" ]; then
    echo "VPC: $VPC_ID"
    echo "Subnets: $SUBNET_IDS"
fi

echo ""

# Check if required files exist
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "Error: CloudFormation template $TEMPLATE_FILE not found"
    exit 1
fi

if [ ! -f "$PYTHON_SCRIPT" ]; then
    echo "Error: Python script $PYTHON_SCRIPT not found"
    exit 1
fi

# Build parameters
PARAMETERS="ParameterKey=ThresholdPercentage,ParameterValue=$THRESHOLD_PERCENTAGE"

if [ ! -z "$NOTIFICATION_EMAIL" ]; then
    PARAMETERS="$PARAMETERS ParameterKey=NotificationEmail,ParameterValue=$NOTIFICATION_EMAIL"
fi

if [ ! -z "$VPC_ID" ]; then
    PARAMETERS="$PARAMETERS ParameterKey=VpcId,ParameterValue=$VPC_ID"
fi

if [ ! -z "$SUBNET_IDS" ]; then
    PARAMETERS="$PARAMETERS ParameterKey=SubnetIds,ParameterValue=\"$SUBNET_IDS\""
fi

if [ "$SCHEDULE_EXPRESSION" != "rate(1 hour)" ]; then
    PARAMETERS="$PARAMETERS ParameterKey=ScheduleExpression,ParameterValue=\"$SCHEDULE_EXPRESSION\""
fi

# Deploy CloudFormation stack
echo "Step 1: Deploying CloudFormation stack..."
aws cloudformation create-stack \
    --stack-name $STACK_NAME \
    --template-body file://$TEMPLATE_FILE \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameters $PARAMETERS

echo "Waiting for stack creation to complete..."
aws cloudformation wait stack-create-complete --stack-name $STACK_NAME

if [ $? -eq 0 ]; then
    echo "✅ CloudFormation stack created successfully"
else
    echo "❌ CloudFormation stack creation failed"
    exit 1
fi

# Get Lambda function name from stack outputs
echo ""
echo "Step 2: Getting Lambda function name..."
FUNCTION_NAME=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --query "Stacks[0].Outputs[?OutputKey=='LambdaFunction'].OutputValue" \
    --output text)

if [ -z "$FUNCTION_NAME" ]; then
    echo "❌ Could not retrieve Lambda function name from stack outputs"
    exit 1
fi

echo "Lambda function: $FUNCTION_NAME"

# Create deployment package
echo ""
echo "Step 3: Creating Lambda deployment package..."
mkdir -p lambda-package
cp $PYTHON_SCRIPT lambda-package/
cd lambda-package
zip -r ../lambda-deployment.zip . > /dev/null
cd ..

echo "✅ Deployment package created"

# Update Lambda function code
echo ""
echo "Step 4: Updating Lambda function code..."
aws lambda update-function-code \
    --function-name $FUNCTION_NAME \
    --zip-file fileb://lambda-deployment.zip > /dev/null

if [ $? -eq 0 ]; then
    echo "✅ Lambda function code updated successfully"
else
    echo "❌ Failed to update Lambda function code"
    exit 1
fi

# Test the function
echo ""
echo "Step 5: Testing Lambda function..."
aws lambda invoke \
    --function-name $FUNCTION_NAME \
    --payload '{}' \
    response.json > /dev/null

if [ $? -eq 0 ]; then
    echo "✅ Lambda function test completed"
    echo "Response:"
    cat response.json | python -m json.tool
else
    echo "❌ Lambda function test failed"
fi

# Clean up temporary files
rm -rf lambda-package lambda-deployment.zip response.json

# Display deployment summary
echo ""
echo "=== Deployment Summary ==="
echo "✅ CloudFormation stack: $STACK_NAME"
echo "✅ Lambda function: $FUNCTION_NAME"

# Get other outputs
SNS_TOPIC=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --query "Stacks[0].Outputs[?OutputKey=='SNSTopicArn'].OutputValue" \
    --output text)

if [ ! -z "$SNS_TOPIC" ]; then
    echo "✅ SNS Topic: $SNS_TOPIC"
fi

S3_BUCKET=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --query "Stacks[0].Outputs[?OutputKey=='S3BucketName'].OutputValue" \
    --output text 2>/dev/null)

if [ ! -z "$S3_BUCKET" ] && [ "$S3_BUCKET" != "Not using S3 storage" ]; then
    echo "✅ S3 Bucket: $S3_BUCKET"
fi

DYNAMODB_TABLE=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --query "Stacks[0].Outputs[?OutputKey=='DynamoDBTableName'].OutputValue" \
    --output text 2>/dev/null)

if [ ! -z "$DYNAMODB_TABLE" ]; then
    echo "✅ DynamoDB Table: $DYNAMODB_TABLE"
fi

echo ""
echo "=== Security Features Enabled ==="
echo "🔒 SNS topic encryption with KMS"
echo "🔒 DynamoDB encryption with customer-managed keys"
echo "🔒 Lambda environment variable encryption"
echo "🔒 Dead Letter Queue for failed executions"
echo "🔒 S3 access logging"
echo "🔒 Comprehensive IAM permissions"

echo ""
echo "=== Next Steps ==="
echo "1. Monitor CloudWatch logs: aws logs tail /aws/lambda/$FUNCTION_NAME --follow"
echo "2. Check function execution: aws lambda invoke --function-name $FUNCTION_NAME --payload '{}' test-response.json"

if [ ! -z "$SNS_TOPIC" ] && [ -z "$NOTIFICATION_EMAIL" ]; then
    echo "3. Subscribe to alerts: aws sns subscribe --topic-arn $SNS_TOPIC --protocol email --notification-endpoint your-email@example.com"
fi

echo ""
echo "🎉 Deployment completed successfully!"
echo "The Connect Quota Monitor is now running automatically on schedule: $SCHEDULE_EXPRESSION"
echo ""
echo "📚 For detailed documentation, see:"
echo "   - Security improvements: Check the security scan report fixes"
echo "   - Monitoring capabilities: All latest Connect APIs and services included"
echo "   - Troubleshooting: CloudWatch logs and Dead Letter Queue available"