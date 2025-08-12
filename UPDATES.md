# Amazon Connect Service Quota Monitor - Updates

This document outlines the updates made to the Amazon Connect Service Quota Monitor to support the latest Amazon Connect features and APIs.

## New Features Added

### Additional Amazon Connect Services Support

The updated solution now monitors quotas for these additional Amazon Connect services:

1. **Amazon Connect Tasks**
   - Tasks per instance
   - Concurrent tasks per instance
   - Task templates per instance

2. **Amazon Connect Cases**
   - Cases domains per instance
   - Case fields per domain
   - Case templates per domain

3. **Amazon Connect Customer Profiles**
   - Customer profiles domains per account
   - Profile object types per domain

4. **Amazon Connect Voice ID**
   - Voice ID domains per account
   - Speakers per domain
   - Fraudsters per domain

5. **Amazon Connect Wisdom**
   - Wisdom knowledge bases per instance
   - Wisdom content per knowledge base

6. **Amazon Connect Contact Lens**
   - Contact Lens real-time analysis per instance

7. **Amazon Connect Outbound Campaigns**
   - Outbound campaigns per instance

8. **Amazon Connect Contact Evaluations**
   - Evaluation forms per instance

### Additional Core Connect Features

1. **Agent Workspace**
   - Agent statuses per instance
   - Prompts per instance

2. **Phone Numbers**
   - Updated to use the newer ListPhoneNumbersV2 API

## Technical Improvements

### Enhanced API Support

1. **Multi-Service Client Support**
   - Added support for multiple AWS service clients:
     - connectcases
     - customer-profiles
     - voice-id
     - wisdom
     - connect-campaigns

2. **Enhanced Pagination Support**
   - Improved pagination handling for all APIs
   - Added support for parent-child resource relationships

3. **CloudWatch Metrics**
   - Added support for additional CloudWatch metrics and namespaces

### IAM Policy Updates

The IAM policy has been updated to include permissions for all the new APIs:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "connect:ListInstances",
                "connect:ListUsers",
                "connect:ListQueues",
                "connect:ListPhoneNumbers",
                "connect:ListHoursOfOperations",
                "connect:ListContactFlows",
                "connect:ListRoutingProfiles",
                "connect:ListSecurityProfiles",
                "connect:ListQuickConnects",
                "connect:DescribeUserHierarchyStructure",
                "connect:ListAgentStatuses",
                "connect:ListPrompts",
                "connect:ListTasks",
                "connect:ListTaskTemplates",
                "connect:ListEvaluationForms",
                "connect:ListPhoneNumbersV2"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "connectcases:ListDomains",
                "connectcases:ListFields",
                "connectcases:ListTemplates"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "profile:ListDomains",
                "profile:ListProfileObjectTypes"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "voiceid:ListDomains",
                "voiceid:ListSpeakers",
                "voiceid:ListFraudsters"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "wisdom:ListKnowledgeBases",
                "wisdom:ListContent"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "connect-campaigns:ListCampaigns"
            ],
            "Resource": "*"
        }
    ]
}
```

## Implementation Notes

The updated solution maintains backward compatibility with the original implementation while adding support for the latest Amazon Connect features. The core monitoring functionality remains the same, but with expanded coverage for newer services and quotas.

To use the updated solution:

1. Deploy using the updated CloudFormation template
2. The solution will automatically detect and monitor all applicable quotas
3. No additional configuration is required

## Future Enhancements

As Amazon Connect continues to evolve with new features and services, this solution can be further enhanced to monitor additional quotas. The modular design makes it easy to add support for new services as they become available.