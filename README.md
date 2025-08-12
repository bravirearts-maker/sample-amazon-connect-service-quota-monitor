# Amazon Connect Service Quota Monitor

A comprehensive CloudFormation-deployable solution that automatically monitors Amazon Connect service quotas and sends alerts when utilization approaches limits. This tool tracks quotas across all Connect features including voice, chat, tasks, cases, customer profiles, voice ID, wisdom, and outbound campaigns. It provides early warning for potential service disruptions, helping maintain reliable contact center operations.

## 🚀 Quick Start

Deploy this solution in **under 5 minutes** using AWS CloudFormation:

### Option A: Complete Deployment Script (Easiest)
```bash
chmod +x deploy_cloudformation.sh
NOTIFICATION_EMAIL=your-email@example.com ./deploy_cloudformation.sh
```

### Option B: Manual CloudFormation Deployment
```bash
# Deploy stack
aws cloudformation create-stack \
  --stack-name ConnectQuotaMonitor \
  --template-body file://connect-quota-monitor-cfn.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameters \
    ParameterKey=ThresholdPercentage,ParameterValue=80 \
    ParameterKey=NotificationEmail,ParameterValue=your-email@example.com

# Wait for completion
aws cloudformation wait stack-create-complete --stack-name ConnectQuotaMonitor

# Update Lambda function code
FUNCTION_NAME=$(aws cloudformation describe-stacks --stack-name ConnectQuotaMonitor --query "Stacks[0].Outputs[?OutputKey=='LambdaFunction'].OutputValue" --output text)
zip lambda-deployment.zip connect-quota-monitor.py
aws lambda update-function-code --function-name $FUNCTION_NAME --zip-file fileb://lambda-deployment.zip
```

## ✨ Features

- **🔄 Automated Monitoring**: Runs on configurable schedule (default: hourly) with no manual intervention
- **📊 Comprehensive Coverage**: Monitors all Connect service quotas including latest APIs
- **🏢 Multi-Instance Support**: Monitors all Connect instances across your AWS account
- **⚙️ Configurable Thresholds**: Set custom alert thresholds (default: 80%)
- **📧 Encrypted Alerts**: Automated SNS email notifications with KMS encryption
- **💾 Secure Storage**: Historical data in S3 and/or DynamoDB with encryption
- **🔒 Enterprise Security**: KMS encryption, VPC support, Dead Letter Queue
- **📈 Advanced Analytics**: Historical utilization tracking and trend analysis
- **🛡️ Latest APIs**: Support for Tasks, Cases, Voice ID, Wisdom, Customer Profiles
- **🔍 Comprehensive Monitoring**: Covers all Connect features and custom CXP implementations

## 📋 Prerequisites

- AWS CLI configured with appropriate permissions
- An AWS account with Amazon Connect instances
- Email address for receiving alerts

## 🛠️ Installation

### Option 1: CloudFormation (Recommended)

1. **Clone this repository**:
   ```bash
   git clone <repository-url>
   cd connect-quota-monitor
   ```

2. **Deploy the stack**:
   ```bash
   aws cloudformation create-stack \
     --stack-name ConnectQuotaMonitor \
     --template-body file://connect-quota-monitor-cfn.yaml \
     --capabilities CAPABILITY_NAMED_IAM \
     --parameters \
       ParameterKey=ThresholdPercentage,ParameterValue=80 \
       ParameterKey=NotificationEmail,ParameterValue=your-email@example.com \
       ParameterKey=CreateS3Bucket,ParameterValue=true \
       ParameterKey=UseDynamoDBStorage,ParameterValue=true
   ```

3. **Confirm email subscription**:
   - Check your email for SNS subscription confirmation
   - Click the confirmation link

4. **Verify deployment**:
   ```bash
   aws cloudformation describe-stacks --stack-name ConnectQuotaMonitor
   ```

### Option 2: Manual Lambda Deployment

Use the provided deployment script:

```bash
chmod +x deploy_lambda.sh
./deploy_lambda.sh
```

## ⚙️ Configuration Parameters

| Parameter | Description | Default | Required |
|-----------|-------------|---------|----------|
| `ThresholdPercentage` | Alert threshold percentage | 80 | No |
| `NotificationEmail` | Email for alerts | - | Yes |
| `CreateS3Bucket` | Create S3 bucket for storage | true | No |
| `S3BucketName` | Custom S3 bucket name | Auto-generated | No |
| `UseDynamoDBStorage` | Enable DynamoDB storage | true | No |
| `DynamoDBTableName` | DynamoDB table name | ConnectQuotaMonitor | No |

## 📊 Monitored Quotas

### User & Identity Management
- Active users per instance
- User hierarchy levels
- Agent statuses per instance

### Voice Operations
- Concurrent calls per instance
- Queues per instance
- Hours of operation per instance
- Phone numbers per instance
- Quick connects per instance
- Contact flows per instance
- Routing profiles per instance
- Security profiles per instance
- Prompts per instance

### Digital Channels
- Concurrent active chats per instance
- Chat duration limits
- Message attachments per chat

### Tasks & Cases
- Tasks per instance
- Concurrent tasks per instance
- Task templates per instance
- Cases domains per instance
- Case fields per domain
- Case templates per domain

### Advanced Connect Services
- Customer profiles domains per account
- Profile object types per domain
- Voice ID domains per account
- Speakers per domain
- Fraudsters per domain
- Wisdom knowledge bases per instance
- Wisdom content per knowledge base
- Contact Lens real-time analysis per instance
- Outbound campaigns per instance
- Evaluation forms per instance

### API Rate Limits
- StartChatContact API requests
- GetCurrentMetricData API requests
- GetMetricData API requests
- StartTaskContact API requests
- CreateCase API requests

## 💾 Data Storage

### S3 Storage Structure
```
connect-quota-monitor-bucket/
├── connect-metrics/
│   ├── YYYY-MM-DD/
│   │   └── instance_id/
│   │       └── timestamp.json
│   └── latest/
│       └── instance_id.json
└── connect-reports/
    ├── YYYY/MM/DD/
    │   └── connect_quota_report_timestamp.json
    └── latest/
        └── connect_quota_report.json
```

### DynamoDB Schema
- **Partition Key**: `id` (instance_id or report_id)
- **Sort Key**: `timestamp`
- **Attributes**: Individual quota utilization percentages
- **GSI**: `instance_id` for efficient querying

## 🔧 Customization

### Modify Alert Threshold
```bash
aws lambda update-function-configuration \
  --function-name ConnectQuotaMonitor \
  --environment Variables='{
    "THRESHOLD_PERCENTAGE":"90",
    "ALERT_SNS_TOPIC_ARN":"arn:aws:sns:region:account:topic",
    "S3_BUCKET":"your-bucket",
    "USE_DYNAMODB":"true",
    "DYNAMODB_TABLE":"ConnectQuotaMonitor"
  }'
```

### Custom Scheduling
Edit the CloudWatch Events rule in the CloudFormation template:
```yaml
ScheduleExpression: "rate(30 minutes)"  # Run every 30 minutes
```

## 🔍 Monitoring & Troubleshooting

### Check Lambda Logs
```bash
aws logs tail /aws/lambda/ConnectQuotaMonitor --follow
```

### Test the Function
```bash
aws lambda invoke \
  --function-name ConnectQuotaMonitor \
  --payload '{}' \
  response.json
```

### View CloudFormation Stack
```bash
aws cloudformation describe-stack-resources \
  --stack-name ConnectQuotaMonitor
```

## 📧 Alert Format

Email alerts include:
- **Instance Details**: Name, ID, and region
- **Quota Information**: Current usage vs. limit
- **Utilization Percentage**: Exact percentage used
- **Timestamp**: When the alert was generated
- **Execution ID**: For tracking and debugging

## 🔒 Security

### Enterprise-Grade Security Features
- **🔐 KMS Encryption**: Customer-managed keys for SNS, DynamoDB, and Lambda
- **🌐 VPC Support**: Optional VPC deployment with security groups
- **📮 Dead Letter Queue**: SQS DLQ for failed Lambda executions
- **📊 Access Logging**: S3 access logs for audit trails
- **🔑 Least Privilege**: Minimal IAM permissions for each service
- **🛡️ Environment Encryption**: Lambda environment variables encrypted

### IAM Permissions
The solution uses least privilege access with permissions for:
- Amazon Connect: Read-only access to instances and quotas (including latest APIs)
- Connect Cases: Read access to domains, fields, and templates
- Customer Profiles: Read access to domains and object types
- Voice ID: Read access to domains, speakers, and fraudsters
- Wisdom: Read access to knowledge bases and content
- Connect Campaigns: Read access to campaigns
- Service Quotas: Read access to quota information
- CloudWatch: Metrics and logging
- SNS: Publishing encrypted alerts
- S3: Storage operations with encryption
- DynamoDB: Read/write operations with KMS encryption

### Data Protection
- All sensitive data is sanitized in logs
- Credentials handled via AWS SDK best practices
- Encryption at rest and in transit for all data
- Secure message delivery with KMS encryption
- Point-in-time recovery for DynamoDB

## 🚀 Deployment Verification

After deployment, verify the solution is working:

1. **Check Lambda function exists**:
   ```bash
   aws lambda get-function --function-name ConnectQuotaMonitor
   ```

2. **Verify SNS topic and subscription**:
   ```bash
   aws sns list-subscriptions-by-topic \
     --topic-arn arn:aws:sns:region:account:ConnectQuotaAlerts
   ```

3. **Test email notifications**:
   ```bash
   aws sns publish \
     --topic-arn arn:aws:sns:region:account:ConnectQuotaAlerts \
     --message "Test message" \
     --subject "Test Alert"
   ```

4. **Check CloudWatch Events rule**:
   ```bash
   aws events list-rules --name-prefix ConnectQuotaMonitor
   ```

## 🔄 Updates and Maintenance

### Update the Solution
```bash
aws cloudformation update-stack \
  --stack-name ConnectQuotaMonitor \
  --template-body file://connect-quota-monitor-cfn.yaml \
  --capabilities CAPABILITY_NAMED_IAM
```

### Clean Up
```bash
aws cloudformation delete-stack --stack-name ConnectQuotaMonitor
```

## 📞 Support

For issues or questions:
1. Check CloudWatch Logs for error messages
2. Verify IAM permissions
3. Ensure Connect instances are in the same region
4. Confirm SNS subscription is confirmed

## 📄 License

This project is licensed under the MIT-0 License - see the [LICENSE](LICENSE) file for details.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request


## 📚 Documentation

- **[DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)**: Comprehensive deployment instructions
- **[SECURITY_IMPROVEMENTS.md](SECURITY_IMPROVEMENTS.md)**: Security features and compliance
- **[UPDATES.md](UPDATES.md)**: Latest API updates and enhancements

---

**Ready to deploy?** Run the deployment command above and start monitoring your Connect quotas with enterprise-grade security in minutes! 🚀
