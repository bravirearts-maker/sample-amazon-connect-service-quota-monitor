# Amazon Connect Service Quota Monitor - Deployment Guide

This guide provides comprehensive instructions for deploying the Amazon Connect Service Quota Monitor with different security and configuration options.

## Deployment Options

### Option 1: CloudFormation Deployment (Recommended for Production)

The CloudFormation template provides enterprise-grade security features and is recommended for production deployments.

#### Features Included:
- ✅ SNS topic encryption with KMS
- ✅ DynamoDB encryption with customer-managed KMS keys
- ✅ Lambda environment variable encryption
- ✅ Dead Letter Queue for failed executions
- ✅ Optional VPC deployment
- ✅ S3 access logging
- ✅ Comprehensive IAM permissions
- ✅ Resource tagging and lifecycle policies

#### Basic Deployment:
```bash
aws cloudformation create-stack \
  --stack-name ConnectQuotaMonitor \
  --template-body file://connect-quota-monitor-cfn.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameters \
    ParameterKey=ThresholdPercentage,ParameterValue=80 \
    ParameterKey=NotificationEmail,ParameterValue=your-email@example.com
```

#### VPC Deployment (Enhanced Security):
```bash
aws cloudformation create-stack \
  --stack-name ConnectQuotaMonitor \
  --template-body file://connect-quota-monitor-cfn.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameters \
    ParameterKey=ThresholdPercentage,ParameterValue=80 \
    ParameterKey=NotificationEmail,ParameterValue=your-email@example.com \
    ParameterKey=VpcId,ParameterValue=vpc-xxxxxxxxx \
    ParameterKey=SubnetIds,ParameterValue="subnet-xxxxxxxx,subnet-yyyyyyyy"
```

#### Custom Configuration:
```bash
aws cloudformation create-stack \
  --stack-name ConnectQuotaMonitor \
  --template-body file://connect-quota-monitor-cfn.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameters \
    ParameterKey=ThresholdPercentage,ParameterValue=75 \
    ParameterKey=ScheduleExpression,ParameterValue="rate(30 minutes)" \
    ParameterKey=UseS3Storage,ParameterValue=true \
    ParameterKey=UseDynamoDBStorage,ParameterValue=true \
    ParameterKey=S3BucketName,ParameterValue=my-custom-bucket \
    ParameterKey=NotificationEmail,ParameterValue=admin@company.com
```

#### Post-Deployment Steps for CloudFormation:

1. **Update Lambda Function Code** (Required):
   The CloudFormation template deploys with placeholder code. You need to update it with the actual monitoring code:

   ```bash
   # Create deployment package
   mkdir -p lambda-package
   cp connect-quota-monitor.py lambda-package/
   cd lambda-package
   zip -r ../lambda-deployment.zip .
   cd ..

   # Update Lambda function
   FUNCTION_NAME=$(aws cloudformation describe-stacks --stack-name ConnectQuotaMonitor --query "Stacks[0].Outputs[?OutputKey=='LambdaFunction'].OutputValue" --output text)
   aws lambda update-function-code \
     --function-name $FUNCTION_NAME \
     --zip-file fileb://lambda-deployment.zip

   # Clean up
   rm -rf lambda-package lambda-deployment.zip
   ```

2. **Test the Deployment**:
   ```bash
   # Manually invoke the function
   aws lambda invoke \
     --function-name $FUNCTION_NAME \
     --payload '{}' \
     response.json

   # Check the response
   cat response.json

   # Check CloudWatch logs
   aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/$FUNCTION_NAME"
   ```

### Option 2: Script Deployment (Basic Security)

The deployment script provides a quick setup but with basic security features.

#### Features Included:
- ✅ Basic SNS topic (no encryption)
- ✅ Basic S3 bucket (no access logging)
- ✅ Basic DynamoDB table (no KMS encryption)
- ✅ Standard IAM permissions
- ❌ No Dead Letter Queue
- ❌ No VPC support
- ❌ No environment variable encryption

#### Deployment:
```bash
chmod +x deploy_lambda.sh
./deploy_lambda.sh
```

### Option 3: Manual Deployment

For custom deployments or integration with existing infrastructure.

#### Steps:
1. Create required AWS resources manually
2. Configure IAM roles and policies
3. Deploy Lambda function
4. Set up CloudWatch Events rule
5. Configure monitoring and alerting

## Configuration Parameters

### CloudFormation Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `ThresholdPercentage` | 80 | Alert threshold percentage |
| `LambdaTimeout` | 300 | Lambda timeout in seconds |
| `LambdaMemory` | 256 | Lambda memory in MB |
| `ScheduleExpression` | `rate(1 hour)` | Execution schedule |
| `UseS3Storage` | true | Enable S3 storage |
| `UseDynamoDBStorage` | true | Enable DynamoDB storage |
| `S3BucketName` | (auto-generated) | Custom S3 bucket name |
| `DynamoDBTableName` | ConnectQuotaMonitor | DynamoDB table name |
| `SNSTopicName` | ConnectQuotaAlerts | SNS topic name |
| `NotificationEmail` | (empty) | Email for SNS subscription |
| `VpcId` | (empty) | VPC ID for Lambda deployment |
| `SubnetIds` | (empty) | Subnet IDs for Lambda deployment |

## Security Considerations

### Production Deployment Checklist

- [ ] Use CloudFormation template for deployment
- [ ] Enable VPC deployment if required by security policies
- [ ] Configure custom KMS keys if needed
- [ ] Set up proper monitoring and alerting
- [ ] Review and customize IAM permissions
- [ ] Enable CloudTrail for audit logging
- [ ] Configure backup and disaster recovery
- [ ] Test Dead Letter Queue functionality
- [ ] Verify encryption at rest and in transit

### Network Security

If deploying in a VPC:
- Ensure subnets have internet access for AWS API calls
- Configure security groups to allow HTTPS outbound
- Consider using VPC endpoints for AWS services
- Review network ACLs and routing tables

## Monitoring and Troubleshooting

### CloudWatch Logs
Monitor Lambda execution logs:
```bash
aws logs tail /aws/lambda/ConnectQuotaMonitor --follow
```

### Dead Letter Queue
Check failed executions:
```bash
aws sqs receive-message --queue-url <DLQ-URL>
```

### SNS Topic
Verify alert delivery:
```bash
aws sns list-subscriptions-by-topic --topic-arn <SNS-TOPIC-ARN>
```

## Updating the Solution

### CloudFormation Stack Update
```bash
aws cloudformation update-stack \
  --stack-name ConnectQuotaMonitor \
  --template-body file://connect-quota-monitor-cfn.yaml \
  --capabilities CAPABILITY_NAMED_IAM
```

### Lambda Code Update
```bash
aws lambda update-function-code \
  --function-name <FUNCTION-NAME> \
  --zip-file fileb://lambda-deployment.zip
```

## Cost Optimization

### Estimated Monthly Costs (us-east-1)
- Lambda: $0.20 - $2.00 (depending on execution frequency)
- DynamoDB: $0.25 - $1.00 (depending on data volume)
- S3: $0.02 - $0.10 (depending on storage and requests)
- SNS: $0.50 per million notifications
- KMS: $1.00 per key per month
- CloudWatch Logs: $0.50 per GB ingested

### Cost Optimization Tips
- Adjust Lambda memory based on actual usage
- Use S3 lifecycle policies to archive old data
- Monitor DynamoDB read/write capacity
- Consider using reserved capacity for predictable workloads

## Support and Maintenance

### Regular Maintenance Tasks
- Review and update IAM permissions
- Monitor CloudWatch metrics and alarms
- Update Lambda runtime versions
- Review and rotate KMS keys
- Clean up old logs and data
- Test disaster recovery procedures

### Troubleshooting Common Issues
- Check IAM permissions for API access
- Verify network connectivity in VPC deployments
- Monitor Lambda timeout and memory usage
- Review CloudWatch logs for errors
- Validate SNS topic subscriptions