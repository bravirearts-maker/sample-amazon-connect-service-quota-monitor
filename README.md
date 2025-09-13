# Amazon Connect Service Quota Monitor - Enhanced Edition

A comprehensive solution that monitors **70+ Amazon Connect service quotas** across all Connect services with dynamic instance discovery, consolidated alerting, and intelligent deployment capabilities.

## 🚀 Key Features

- **Comprehensive Coverage**: Monitors 70+ quotas across 15+ service categories
- **Dynamic Discovery**: Automatically discovers Connect instances (no hardcoded IDs)
- **Consolidated Alerts**: One email per instance with all violations
- **Flexible Storage**: Supports S3, DynamoDB, or both
- **Multi-Service Support**: Cases, Customer Profiles, Voice ID, Wisdom, and more
- **Enterprise Security**: KMS encryption, VPC support, data sanitization
- **Intelligent Deployment**: Automatic code size detection with S3 fallback

## 📊 Monitored Services & Quotas

### Core Amazon Connect (15+ quotas)
- Users, Security profiles, Contact flows, Phone numbers
- Lambda functions, Queues, Routing profiles, Hours of operation
- Quick connects, Prompts, Predefined attributes, Flow modules

### Contact Handling (10+ quotas)
- Concurrent calls, chats, tasks, emails
- Campaign calls, Real-time metrics, Historical metrics
- Maximum participants per chat, Queue capacity

### Advanced Services (45+ quotas)
- **Cases**: Domains, Fields, Templates, Layouts
- **Customer Profiles**: Domains, Object types, Integrations
- **Voice ID**: Domains, Speakers, Fraudsters, Watchlists
- **Wisdom**: Knowledge bases, Documents, Assistants
- **Integrations**: App integrations, Event integrations, Lex bots
- **Forecasting**: Forecast groups, Schedules, Data retention
- **API Rate Limits**: Various API request rates

## 🏗️ Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   CloudWatch    │───▶│  Lambda Function │───▶│  SNS Topic      │
│   Events        │    │  (Quota Monitor) │    │  (Alerts)       │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │                        │
                                ▼                        ▼
                       ┌─────────────────┐    ┌─────────────────┐
                       │   DynamoDB      │    │   Email         │
                       │   (Storage)     │    │   Notifications │
                       └─────────────────┘    └─────────────────┘
                                │
                                ▼
                       ┌─────────────────┐
                       │   S3 Bucket     │
                       │   (Optional)    │
                       └─────────────────┘
```

## 📋 Prerequisites

- **AWS CLI** configured with appropriate permissions
- **Amazon Connect instance(s)** in your AWS account
- **Email address** for receiving alerts
- **IAM permissions** for CloudFormation, Lambda, SNS, S3, DynamoDB, Connect

## 🚀 Deployment

### Step 1: Prepare the Code Package

```bash
# Create deployment package
zip lambda-deployment.zip lambda_function.py
```

### Step 2: Deploy CloudFormation Stack

```bash
aws cloudformation create-stack \
  --stack-name ConnectQuotaMonitor \
  --template-body file://connect-quota-monitor-cfn.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameters \
    ParameterKey=ThresholdPercentage,ParameterValue=80 \
    ParameterKey=NotificationEmail,ParameterValue=your-email@company.com \
    ParameterKey=UseS3Storage,ParameterValue=true \
    ParameterKey=UseDynamoDBStorage,ParameterValue=true
```

### Step 3: Deploy Lambda Code

```bash
# Wait for stack creation to complete
aws cloudformation wait stack-create-complete --stack-name ConnectQuotaMonitor

# Update Lambda function with actual code
aws lambda update-function-code \
  --function-name ConnectQuotaMonitor-EnhancedConnectQuotaMonitor \
  --zip-file fileb://lambda-deployment.zip
```

### Step 4: Verify Deployment

```bash
# Test the function
aws lambda invoke \
  --function-name ConnectQuotaMonitor-EnhancedConnectQuotaMonitor \
  --payload '{}' \
  test-response.json

# Check the response
cat test-response.json
```

### Alternative: Using the Deployment Script

```bash
# Make script executable
chmod +x deploy.sh

# Deploy with basic configuration
./deploy.sh --email your-email@company.com --threshold 80

# Deploy with advanced options
./deploy.sh \
  --email your-email@company.com \
  --threshold 85 \
  --runtime python3.12 \
  --memory 1024 \
  --vpc-id vpc-12345678 \
  --subnet-ids subnet-123,subnet-456
```

## ⚙️ Configuration Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `ThresholdPercentage` | 80 | Alert threshold (1-99%) |
| `NotificationEmail` | - | Email for alerts (optional) |
| `LambdaRuntime` | python3.12 | Python runtime version |
| `LambdaMemory` | 512 | Memory in MB (256-10240) |
| `LambdaTimeout` | 600 | Timeout in seconds (60-900) |
| `UseS3Storage` | true | Enable S3 storage |
| `UseDynamoDBStorage` | true | Enable DynamoDB storage |
| `ScheduleExpression` | rate(1 hour) | Monitoring frequency |

## 📧 Alert Examples

### Instance-Level Alert
```
Subject: Connect Quota Alert - Instance: MyConnectInstance (2 violations)

Instance: MyConnectInstance (12345678-1234-1234-1234-123456789012)
Threshold: 80%
Violations Found: 2

VIOLATIONS:
• Contact flows per instance: 147/100 (147.0%) - VIOLATION
• Lambda functions per instance: 42/50 (84.0%) - VIOLATION

SUMMARY:
• Total quotas monitored: 24
• Maximum utilization: 147.0%
• Average utilization: 16.8%
```

## � Data Storage

### DynamoDB Structure
```json
{
  "id": "instance_12345678_1640995200",
  "timestamp": "2025-09-12T23:08:19.645730",
  "instance_id": "12345678-1234-1234-1234-123456789012",
  "instance_alias": "MyConnectInstance",
  "metrics_count": 24,
  "violations_count": 1,
  "metrics": [...],
  "summary": {
    "max_utilization": 147.0,
    "avg_utilization": 16.8
  }
}
```

### S3 Structure
```
s3://bucket/
├── connect-metrics/
│   ├── 2025/09/12/instance-metrics-timestamp.json
│   └── 2025/09/12/account-metrics-timestamp.json
└── connect-reports/
    └── 2025/09/12/execution-summary-timestamp.json
```

## 🔧 Post-Deployment Configuration

### Update Alert Threshold
```bash
aws lambda update-function-configuration \
  --function-name ConnectQuotaMonitor-EnhancedConnectQuotaMonitor \
  --environment Variables='{
    "THRESHOLD_PERCENTAGE": "85",
    "ALERT_SNS_TOPIC_ARN": "arn:aws:sns:region:account:topic",
    "USE_S3_STORAGE": "true",
    "USE_DYNAMODB": "true"
  }'
```

### Add Email Subscribers
```bash
aws sns subscribe \
  --topic-arn arn:aws:sns:region:account:ConnectQuotaAlerts \
  --protocol email \
  --notification-endpoint admin2@company.com
```

## 🔍 Monitoring & Troubleshooting

### Check Execution Logs
```bash
aws logs tail /aws/lambda/ConnectQuotaMonitor-EnhancedConnectQuotaMonitor --follow
```

### Query DynamoDB Data
```bash
aws dynamodb scan --table-name ConnectQuotaMonitor --max-items 5
```

### Verify SNS Topic
```bash
aws sns get-topic-attributes --topic-arn your-sns-topic-arn
```

### Common Issues & Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| No alerts received | Email not confirmed | Check email and confirm SNS subscription |
| Permission errors | Missing IAM permissions | Review CloudFormation IAM policies |
| Quota over 100% | Soft limits exceeded | Normal behavior - existing resources remain |
| Missing quotas | Service not enabled | Enable Connect features (Cases, Voice ID, etc.) |
| Rate limit errors | Too many API calls | Normal - function handles gracefully |

## � Costt Estimation

**Monthly Costs (typical):**
- **Lambda**: ~$2-5 (based on hourly execution)
- **DynamoDB**: ~$1-3 (quota data storage)
- **S3**: ~$0.50-1 (optional storage)
- **SNS**: ~$0.10-0.50 (notifications)
- **CloudWatch**: ~$0.50-1 (logs)

**Total: ~$4-10/month** for comprehensive Connect monitoring

## 🔒 Security Features

- ✅ **KMS Encryption**: SNS topics, DynamoDB tables, Lambda environment
- ✅ **Data Sanitization**: Removes sensitive data from logs
- ✅ **IAM Least Privilege**: Minimal required permissions
- ✅ **VPC Support**: Optional VPC deployment
- ✅ **Dead Letter Queue**: Failed execution handling
- ✅ **Reserved Concurrency**: Prevents excessive executions

## 📈 Performance

- **Execution Time**: 60-120 seconds (depending on instance count)
- **Memory Usage**: ~100-150 MB (512 MB allocated)
- **Quota Coverage**: 70+ quotas across all Connect services
- **Scalability**: Handles multiple instances automatically
- **Rate Limiting**: Built-in retry logic and graceful degradation

## 🎯 Success Validation

**✅ Deployment is successful when:**
1. CloudFormation stack creates without errors
2. Lambda function executes successfully
3. Email alerts are received for violations
4. DynamoDB contains quota data
5. CloudWatch logs show successful execution
6. All Connect instances are discovered

## 📞 Support

**For issues:**
1. Check CloudWatch logs first
2. Verify IAM permissions
3. Confirm Connect instances are active
4. Review email subscription status

**Common Commands:**
```bash
# Check stack status
aws cloudformation describe-stacks --stack-name ConnectQuotaMonitor

# Manual function execution
aws lambda invoke --function-name ConnectQuotaMonitor-EnhancedConnectQuotaMonitor test.json

# View recent data
aws dynamodb scan --table-name ConnectQuotaMonitor --max-items 3
```

---

## 🎉 Ready to Deploy!

This enhanced Connect Quota Monitor provides enterprise-grade monitoring for your Amazon Connect environment. Follow the deployment steps above to get started with comprehensive quota monitoring in minutes!