#!/usr/bin/env python3
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

"""
Amazon Connect Service Quota Monitor

This script monitors Amazon Connect service quotas and their utilization,
sending alerts when utilization reaches 80% of the quota limit.
"""

import boto3
import logging
import json
from datetime import datetime, timedelta
import os
import sys
import re
from botocore.exceptions import ClientError, BotoCoreError
import uuid
import io

# Configure logging with secure defaults
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger('connect-quota-monitor')

# Sanitize sensitive data from logs
def sanitize_log(message):
    """Sanitize potentially sensitive data from log messages."""
    # Remove any potential AWS account IDs
    message = re.sub(r'\d{12}', '[ACCOUNT_ID]', str(message))
    # Remove any potential ARNs
    message = re.sub(r'arn:aws:[^:\s]+(:[^:\s]+)*', '[ARN]', message)
    return message

# Constants
THRESHOLD_PERCENTAGE = 80  # Alert when utilization reaches 80% of quota
EXECUTION_ID = str(uuid.uuid4())  # Unique ID for this execution for traceability

# Define Connect quota codes and their corresponding metrics
CONNECT_QUOTA_METRICS = {
    # User related quotas
    'L-CE1CB913': {  # Active users per instance
        'name': 'Active users',
        'method': 'api_count',
        'api': 'list_users'
    },
    'L-5243FFAF': {  # User hierarchy levels
        'name': 'User hierarchy levels',
        'method': 'api_count',
        'api': 'describe_user_hierarchy_structure'
    },
    'L-F0B6A36F': {  # Agent statuses per instance
        'name': 'Agent statuses',
        'method': 'api_count',
        'api': 'list_agent_statuses'
    },
    
    # Voice related quotas
    'L-F7D9D426': {  # Concurrent calls per instance
        'name': 'Concurrent calls',
        'method': 'cloudwatch',
        'metric_name': 'ConcurrentCalls',
        'statistic': 'Maximum'
    },
    'L-3E847AB3': {  # Queues per instance
        'name': 'Queues',
        'method': 'api_count',
        'api': 'list_queues'
    },
    'L-5BDCD1F1': {  # Hours of operation per instance
        'name': 'Hours of operation',
        'method': 'api_count',
        'api': 'list_hours_of_operations'
    },
    'L-B764748E': {  # Phone numbers per instance
        'name': 'Phone numbers',
        'method': 'api_count',
        'api': 'list_phone_numbers'
    },
    'L-D77A0D2A': {  # Quick connects per instance
        'name': 'Quick connects',
        'method': 'api_count',
        'api': 'list_quick_connects'
    },
    'L-5E3B1C3D': {  # Contact flows per instance
        'name': 'Contact flows',
        'method': 'api_count',
        'api': 'list_contact_flows'
    },
    'L-0E4BD33B': {  # Routing profiles per instance
        'name': 'Routing profiles',
        'method': 'api_count',
        'api': 'list_routing_profiles'
    },
    'L-0B825C74': {  # Security profiles per instance
        'name': 'Security profiles',
        'method': 'api_count',
        'api': 'list_security_profiles'
    },
    'L-D4B511E9': {  # Prompts per instance
        'name': 'Prompts',
        'method': 'api_count',
        'api': 'list_prompts'
    },
    
    # Chat related quotas
    'L-5E34B00F': {  # Concurrent active chats per instance
        'name': 'Concurrent active chats',
        'method': 'cloudwatch',
        'metric_name': 'ConcurrentActiveChats',
        'statistic': 'Maximum'
    },
    'L-7A2A1083': {  # Attachments per message
        'name': 'Attachments per message',
        'method': 'not_measurable'  # Can't be measured directly
    },
    'L-E7F0B6BC': {  # Chat duration in minutes
        'name': 'Chat duration',
        'method': 'cloudwatch',
        'metric_name': 'ChatDuration',
        'statistic': 'Average'
    },
    
    # Tasks related quotas
    'L-8F0B8D70': {  # Tasks per instance
        'name': 'Tasks',
        'method': 'api_count',
        'api': 'list_tasks'
    },
    'L-D98F7163': {  # Concurrent tasks per instance
        'name': 'Concurrent tasks',
        'method': 'cloudwatch',
        'metric_name': 'ConcurrentTasks',
        'statistic': 'Maximum'
    },
    'L-B2C17E4F': {  # Task templates per instance
        'name': 'Task templates',
        'method': 'api_count',
        'api': 'list_task_templates'
    },
    
    # Cases related quotas
    'L-A2D8DC6A': {  # Cases domains per instance
        'name': 'Cases domains',
        'method': 'api_count',
        'api': 'list_domains',
        'service': 'connectcases'
    },
    'L-F6E5F386': {  # Case fields per domain
        'name': 'Case fields per domain',
        'method': 'api_count_multi',
        'api': 'list_fields',
        'service': 'connectcases',
        'parent_api': 'list_domains',
        'parent_service': 'connectcases',
        'parent_key': 'domainId'
    },
    'L-0437DC6A': {  # Case templates per domain
        'name': 'Case templates per domain',
        'method': 'api_count_multi',
        'api': 'list_templates',
        'service': 'connectcases',
        'parent_api': 'list_domains',
        'parent_service': 'connectcases',
        'parent_key': 'domainId'
    },
    
    # Customer Profiles related quotas
    'L-F6B3D5D2': {  # Customer profiles domains per account
        'name': 'Customer profiles domains',
        'method': 'api_count',
        'api': 'list_domains',
        'service': 'customer-profiles'
    },
    'L-BD0F46E9': {  # Profile object types per domain
        'name': 'Profile object types per domain',
        'method': 'api_count_multi',
        'api': 'list_profile_object_types',
        'service': 'customer-profiles',
        'parent_api': 'list_domains',
        'parent_service': 'customer-profiles',
        'parent_key': 'DomainName'
    },
    
    # Voice ID related quotas
    'L-4AA0D667': {  # Voice ID domains per account
        'name': 'Voice ID domains',
        'method': 'api_count',
        'api': 'list_domains',
        'service': 'voice-id'
    },
    'L-9B8870E3': {  # Speakers per domain
        'name': 'Speakers per domain',
        'method': 'api_count_multi',
        'api': 'list_speakers',
        'service': 'voice-id',
        'parent_api': 'list_domains',
        'parent_service': 'voice-id',
        'parent_key': 'DomainId'
    },
    'L-D9A8CB68': {  # Fraudsters per domain
        'name': 'Fraudsters per domain',
        'method': 'api_count_multi',
        'api': 'list_fraudsters',
        'service': 'voice-id',
        'parent_api': 'list_domains',
        'parent_service': 'voice-id',
        'parent_key': 'DomainId'
    },
    
    # Wisdom related quotas
    'L-C7F2E7AB': {  # Wisdom knowledge bases per instance
        'name': 'Wisdom knowledge bases',
        'method': 'api_count',
        'api': 'list_knowledge_bases',
        'service': 'wisdom'
    },
    'L-D94C4BF0': {  # Wisdom content per knowledge base
        'name': 'Wisdom content per knowledge base',
        'method': 'api_count_multi',
        'api': 'list_content',
        'service': 'wisdom',
        'parent_api': 'list_knowledge_bases',
        'parent_service': 'wisdom',
        'parent_key': 'knowledgeBaseId'
    },
    
    # Contact Lens related quotas
    'L-E8F843D1': {  # Contact Lens real-time analysis per instance
        'name': 'Contact Lens real-time analysis',
        'method': 'cloudwatch',
        'metric_name': 'RealTimeAnalysisSegmentsPerInterval',
        'statistic': 'Sum',
        'namespace': 'AWS/Connect/ContactLens'
    },
    
    # Outbound campaigns related quotas
    'L-F0B6A36F': {  # Outbound campaigns per instance
        'name': 'Outbound campaigns',
        'method': 'api_count',
        'api': 'list_campaigns',
        'service': 'connect-campaigns'
    },
    
    # Contact evaluations related quotas
    'L-D4B511E9': {  # Evaluation forms per instance
        'name': 'Evaluation forms',
        'method': 'api_count',
        'api': 'list_evaluation_forms'
    },
    
    # API related quotas
    'L-B7D4D8B0': {  # Rate of StartChatContact API requests
        'name': 'StartChatContact API rate',
        'method': 'cloudwatch_api',
        'operation': 'StartChatContact'
    },
    'L-3F4AAB35': {  # Rate of GetCurrentMetricData API requests
        'name': 'GetCurrentMetricData API rate',
        'method': 'cloudwatch_api',
        'operation': 'GetCurrentMetricData'
    },
    'L-A2C60A83': {  # Rate of GetMetricData API requests
        'name': 'GetMetricData API rate',
        'method': 'cloudwatch_api',
        'operation': 'GetMetricData'
    },
    'L-D98F7163': {  # Rate of StartTaskContact API requests
        'name': 'StartTaskContact API rate',
        'method': 'cloudwatch_api',
        'operation': 'StartTaskContact'
    },
    'L-B2C17E4F': {  # Rate of CreateCase API requests
        'name': 'CreateCase API rate',
        'method': 'cloudwatch_api',
        'operation': 'CreateCase',
        'namespace': 'AWS/ConnectCases'
    }
}

class ConnectQuotaMonitor:
    def __init__(self, region_name=None, profile_name=None, s3_bucket=None, use_dynamodb=False, dynamodb_table=None):
        """Initialize the Connect Quota Monitor with optional region and profile."""
        try:
            # Validate and create session with appropriate security
            session = boto3.Session(profile_name=profile_name, region_name=region_name)
            
            # Verify credentials are available
            if not session.get_credentials():
                raise ValueError("No AWS credentials found. Please configure AWS credentials.")
                
            # Create clients with appropriate retry configuration and timeouts
            self.connect_client = session.client('connect', 
                                               config=boto3.config.Config(retries={'max_attempts': 3}))
            self.service_quotas_client = session.client('service-quotas',
                                                      config=boto3.config.Config(retries={'max_attempts': 3}))
            self.cloudwatch_client = session.client('cloudwatch',
                                                  config=boto3.config.Config(retries={'max_attempts': 3}))
            self.sns_client = session.client('sns',
                                           config=boto3.config.Config(retries={'max_attempts': 3}))
            
            # Initialize S3 client if bucket is provided
            self.s3_bucket = s3_bucket
            if s3_bucket:
                self.s3_client = session.client('s3',
                                              config=boto3.config.Config(retries={'max_attempts': 3}))
                logger.info(f"S3 storage enabled with bucket: {sanitize_log(s3_bucket)}")
            else:
                self.s3_client = None
                
            # Initialize DynamoDB client if requested
            self.use_dynamodb = use_dynamodb
            self.dynamodb_table = dynamodb_table
            if use_dynamodb and dynamodb_table:
                self.dynamodb_client = session.client('dynamodb',
                                                    config=boto3.config.Config(retries={'max_attempts': 3}))
                self.dynamodb_resource = session.resource('dynamodb')
                logger.info(f"DynamoDB storage enabled with table: {sanitize_log(dynamodb_table)}")
                
                # Ensure the DynamoDB table exists
                self._ensure_dynamodb_table()
            else:
                self.dynamodb_client = None
                self.dynamodb_resource = None
            
            # Initialize additional clients for extended Connect services
            self.additional_clients = self._initialize_additional_clients(session, region_name)
            
            # Store region for logging and reference
            self.region = region_name or session.region_name
            logger.info(f"Initialized ConnectQuotaMonitor in region {self.region}")
            
        except (ClientError, BotoCoreError, ValueError) as e:
            logger.error(f"Failed to initialize AWS clients: {sanitize_log(str(e))}")
            raise
            
    def _initialize_additional_clients(self, session, region_name=None):
        """Initialize additional AWS clients needed for the updated quota monitoring."""
        clients = {}
        
        try:
            # Configure retry settings
            config = boto3.config.Config(retries={'max_attempts': 3})
            
            # Initialize Connect Cases client
            clients['connectcases'] = session.client('connectcases', 
                                                  region_name=region_name,
                                                  config=config)
            
            # Initialize Customer Profiles client
            clients['customer-profiles'] = session.client('customer-profiles', 
                                                       region_name=region_name,
                                                       config=config)
            
            # Initialize Voice ID client
            clients['voice-id'] = session.client('voice-id', 
                                               region_name=region_name,
                                               config=config)
            
            # Initialize Wisdom client
            clients['wisdom'] = session.client('wisdom', 
                                             region_name=region_name,
                                             config=config)
            
            # Initialize Connect Campaigns client
            clients['connect-campaigns'] = session.client('connect-campaigns', 
                                                       region_name=region_name,
                                                       config=config)
            
            logger.info(f"Initialized additional AWS clients for extended Connect services")
            
        except (ClientError, BotoCoreError) as e:
            logger.warning(f"Some additional clients could not be initialized: {sanitize_log(str(e))}")
            logger.warning("Monitoring will continue with available clients only")
            
        return clients
            
    def _ensure_dynamodb_table(self):
        """Ensure the DynamoDB table exists, create it if it doesn't."""
        try:
            # Check if table exists
            self.dynamodb_client.describe_table(TableName=self.dynamodb_table)
            logger.info(f"DynamoDB table {sanitize_log(self.dynamodb_table)} exists")
        except ClientError as e:
            if e.response['Error']['Code'] == 'ResourceNotFoundException':
                # Table doesn't exist, create it
                logger.info(f"Creating DynamoDB table {sanitize_log(self.dynamodb_table)}")
                
                table = self.dynamodb_resource.create_table(
                    TableName=self.dynamodb_table,
                    KeySchema=[
                        {
                            'AttributeName': 'id',
                            'KeyType': 'HASH'  # Partition key
                        },
                        {
                            'AttributeName': 'timestamp',
                            'KeyType': 'RANGE'  # Sort key
                        }
                    ],
                    AttributeDefinitions=[
                        {
                            'AttributeName': 'id',
                            'AttributeType': 'S'
                        },
                        {
                            'AttributeName': 'timestamp',
                            'AttributeType': 'S'
                        },
                        {
                            'AttributeName': 'instance_id',
                            'AttributeType': 'S'
                        }
                    ],
                    GlobalSecondaryIndexes=[
                        {
                            'IndexName': 'InstanceIdIndex',
                            'KeySchema': [
                                {
                                    'AttributeName': 'instance_id',
                                    'KeyType': 'HASH'
                                },
                                {
                                    'AttributeName': 'timestamp',
                                    'KeyType': 'RANGE'
                                }
                            ],
                            'Projection': {
                                'ProjectionType': 'ALL'
                            },
                            'ProvisionedThroughput': {
                                'ReadCapacityUnits': 5,
                                'WriteCapacityUnits': 5
                            }
                        }
                    ],
                    ProvisionedThroughput={
                        'ReadCapacityUnits': 5,
                        'WriteCapacityUnits': 5
                    }
                )
                
                # Wait for table to be created
                table.meta.client.get_waiter('table_exists').wait(TableName=self.dynamodb_table)
                logger.info(f"DynamoDB table {sanitize_log(self.dynamodb_table)} created successfully")
        
    def get_connect_instances(self):
        """Get list of all Amazon Connect instances in the account."""
        instances = []
        try:
            paginator = self.connect_client.get_paginator('list_instances')
            
            for page in paginator.paginate():
                instances.extend(page['InstanceSummaryList'])
                
            logger.info(f"Found {len(instances)} Connect instances")
            return instances
            
        except ClientError as e:
            error_code = e.response['Error']['Code']
            error_msg = e.response['Error']['Message']
            logger.error(f"Failed to list Connect instances: {error_code} - {sanitize_log(error_msg)}")
            if error_code == 'AccessDeniedException':
                logger.error("Insufficient permissions to list Connect instances. Check IAM permissions.")
            raise
    
    def get_service_quotas(self):
        """Get Amazon Connect service quotas."""
        quotas = []
        try:
            paginator = self.service_quotas_client.get_paginator('list_service_quotas')
            
            for page in paginator.paginate(ServiceCode='connect'):
                quotas.extend(page['Quotas'])
                
            # Filter to include only the quotas we know how to monitor
            monitorable_quotas = [q for q in quotas if q['QuotaCode'] in CONNECT_QUOTA_METRICS]
            
            logger.info(f"Found {len(monitorable_quotas)} monitorable Connect service quotas out of {len(quotas)} total")
            return monitorable_quotas
            
        except ClientError as e:
            error_code = e.response['Error']['Code']
            error_msg = e.response['Error']['Message']
            logger.error(f"Failed to list service quotas: {error_code} - {sanitize_log(error_msg)}")
            if error_code == 'AccessDeniedException':
                logger.error("Insufficient permissions to list service quotas. Check IAM permissions.")
            raise
    
    def get_quota_utilization(self, instance_id, quota):
        """
        Get current utilization for a specific quota based on its measurement method.
        """
        quota_code = quota['QuotaCode']
        quota_name = quota['QuotaName']
        quota_value = quota['Value']
        
        # Skip if we don't know how to monitor this quota
        if quota_code not in CONNECT_QUOTA_METRICS:
            logger.info(f"No monitoring configuration for quota: {quota_name} ({quota_code})")
            return None
            
        metric_config = CONNECT_QUOTA_METRICS[quota_code]
        method = metric_config.get('method')
        
        try:
            # Method 1: Count resources via API pagination
            if method == 'api_count':
                service = metric_config.get('service', 'connect')
                api_name = metric_config.get('api')
                
                # Get the appropriate client
                if service == 'connect':
                    client = self.connect_client
                else:
                    client = self.additional_clients.get(service)
                    if not client:
                        logger.warning(f"No client available for service {service}")
                        return None
                
                if not hasattr(client, api_name):
                    logger.warning(f"API {api_name} not available in {service} client")
                    return None
                    
                # Get the API method
                api_method = getattr(client, api_name)
                
                # Handle different API patterns based on service and API
                if service == 'connect':
                    if api_name == 'list_users':
                        return self._count_via_pagination(client, api_method, 'UserSummaryList', 
                                                      {'InstanceId': instance_id}, quota)
                                                      
                    elif api_name == 'list_queues':
                        return self._count_via_pagination(client, api_method, 'QueueSummaryList', 
                                                      {'InstanceId': instance_id, 'QueueTypes': ['STANDARD']}, quota)
                                                      
                    elif api_name == 'list_phone_numbers':
                        return self._count_via_pagination(client, api_method, 'PhoneNumberSummaryList', 
                                                      {'InstanceId': instance_id}, quota)
                                                      
                    elif api_name == 'list_hours_of_operations':
                        return self._count_via_pagination(client, api_method, 'HoursOfOperationSummaryList', 
                                                      {'InstanceId': instance_id}, quota)
                                                      
                    elif api_name == 'list_contact_flows':
                        return self._count_via_pagination(client, api_method, 'ContactFlowSummaryList', 
                                                      {'InstanceId': instance_id}, quota)
                                                      
                    elif api_name == 'list_routing_profiles':
                        return self._count_via_pagination(client, api_method, 'RoutingProfileSummaryList', 
                                                      {'InstanceId': instance_id}, quota)
                                                      
                    elif api_name == 'list_security_profiles':
                        return self._count_via_pagination(client, api_method, 'SecurityProfileSummaryList', 
                                                      {'InstanceId': instance_id}, quota)
                                                      
                    elif api_name == 'list_quick_connects':
                        return self._count_via_pagination(client, api_method, 'QuickConnectSummaryList', 
                                                      {'InstanceId': instance_id}, quota)
                                                      
                    elif api_name == 'list_agent_statuses':
                        return self._count_via_pagination(client, api_method, 'AgentStatusSummaryList', 
                                                      {'InstanceId': instance_id}, quota)
                                                      
                    elif api_name == 'list_prompts':
                        return self._count_via_pagination(client, api_method, 'PromptSummaryList', 
                                                      {'InstanceId': instance_id}, quota)
                                                      
                    elif api_name == 'list_tasks':
                        return self._count_via_pagination(client, api_method, 'TaskSummaryList', 
                                                      {'InstanceId': instance_id}, quota)
                                                      
                    elif api_name == 'list_task_templates':
                        return self._count_via_pagination(client, api_method, 'TaskTemplates', 
                                                      {'InstanceId': instance_id}, quota)
                                                      
                    elif api_name == 'list_evaluation_forms':
                        return self._count_via_pagination(client, api_method, 'EvaluationFormSummaryList', 
                                                      {'InstanceId': instance_id}, quota)
                                                      
                    elif api_name == 'describe_user_hierarchy_structure':
                        try:
                            response = api_method(InstanceId=instance_id)
                            if 'HierarchyStructure' in response and 'LevelOne' in response['HierarchyStructure']:
                                # Count the number of levels in the hierarchy
                                level_count = 1  # Start with 1 for the root level
                                hierarchy = response['HierarchyStructure']
                                
                                if hierarchy.get('LevelOne') and hierarchy['LevelOne'].get('Name'):
                                    level_count += 1
                                if hierarchy.get('LevelTwo') and hierarchy['LevelTwo'].get('Name'):
                                    level_count += 1
                                if hierarchy.get('LevelThree') and hierarchy['LevelThree'].get('Name'):
                                    level_count += 1
                                if hierarchy.get('LevelFour') and hierarchy['LevelFour'].get('Name'):
                                    level_count += 1
                                if hierarchy.get('LevelFive') and hierarchy['LevelFive'].get('Name'):
                                    level_count += 1
                                    
                                return self._create_utilization_result(quota, level_count)
                            else:
                                return self._create_utilization_result(quota, 0)
                        except ClientError as e:
                            if e.response['Error']['Code'] == 'ResourceNotFoundException':
                                # No hierarchy structure defined
                                return self._create_utilization_result(quota, 0)
                            raise
                
                # Handle other services
                elif service == 'connectcases':
                    if api_name == 'list_domains':
                        # Filter domains by Connect instance ID
                        return self._count_via_pagination(client, api_method, 'domains', 
                                                      {'instanceId': instance_id}, quota)
                
                elif service == 'customer-profiles':
                    if api_name == 'list_domains':
                        # No instance filtering for customer profiles domains
                        return self._count_via_pagination(client, api_method, 'Items', {}, quota)
                
                elif service == 'voice-id':
                    if api_name == 'list_domains':
                        # No instance filtering for voice ID domains
                        return self._count_via_pagination(client, api_method, 'DomainSummaries', {}, quota)
                
                elif service == 'wisdom':
                    if api_name == 'list_knowledge_bases':
                        # Filter knowledge bases by Connect instance ID
                        return self._count_via_pagination(client, api_method, 'knowledgeBaseSummaries', 
                                                      {'instanceId': instance_id}, quota)
                
                elif service == 'connect-campaigns':
                    if api_name == 'list_campaigns':
                        # Filter campaigns by Connect instance ID
                        return self._count_via_pagination(client, api_method, 'campaigns', 
                                                      {'instanceId': instance_id}, quota)
                
                # Default case for API methods not specifically handled
                logger.warning(f"No specific handler for API {api_name} in service {service}")
                return None
                
            # Method 2: Count resources via multi-level API pagination (parent-child relationships)
            elif method == 'api_count_multi':
                service = metric_config.get('service')
                api_name = metric_config.get('api')
                parent_service = metric_config.get('parent_service')
                parent_api = metric_config.get('parent_api')
                parent_key = metric_config.get('parent_key')
                
                # Get the appropriate clients
                if service == 'connect':
                    client = self.connect_client
                else:
                    client = self.additional_clients.get(service)
                    if not client:
                        logger.warning(f"No client available for service {service}")
                        return None
                        
                if parent_service == 'connect':
                    parent_client = self.connect_client
                else:
                    parent_client = self.additional_clients.get(parent_service)
                    if not parent_client:
                        logger.warning(f"No client available for parent service {parent_service}")
                        return None
                
                # Check if APIs exist
                if not hasattr(client, api_name):
                    logger.warning(f"API {api_name} not available in {service} client")
                    return None
                    
                if not hasattr(parent_client, parent_api):
                    logger.warning(f"API {parent_api} not available in {parent_service} client")
                    return None
                    
                # Get the API methods
                api_method = getattr(client, api_name)
                parent_api_method = getattr(parent_client, parent_api)
                
                # First get the parent resources
                parent_resources = []
                
                # Handle different parent API patterns based on service
                if parent_service == 'connect':
                    # Most Connect APIs require instance ID
                    parent_params = {'InstanceId': instance_id}
                    parent_result_key = self._get_result_key_for_api(parent_api)
                    parent_resources = self._get_all_resources_via_pagination(parent_client, parent_api_method, 
                                                                          parent_result_key, parent_params)
                elif parent_service == 'connectcases':
                    if parent_api == 'list_domains':
                        # Filter domains by Connect instance ID
                        parent_params = {'instanceId': instance_id}
                        parent_resources = self._get_all_resources_via_pagination(parent_client, parent_api_method, 
                                                                              'domains', parent_params)
                elif parent_service == 'customer-profiles':
                    if parent_api == 'list_domains':
                        # No instance filtering for customer profiles domains
                        parent_resources = self._get_all_resources_via_pagination(parent_client, parent_api_method, 
                                                                              'Items', {})
                elif parent_service == 'voice-id':
                    if parent_api == 'list_domains':
                        # No instance filtering for voice ID domains
                        parent_resources = self._get_all_resources_via_pagination(parent_client, parent_api_method, 
                                                                              'DomainSummaries', {})
                elif parent_service == 'wisdom':
                    if parent_api == 'list_knowledge_bases':
                        # Filter knowledge bases by Connect instance ID
                        parent_params = {'instanceId': instance_id}
                        parent_resources = self._get_all_resources_via_pagination(parent_client, parent_api_method, 
                                                                              'knowledgeBaseSummaries', parent_params)
                
                # Now count child resources across all parent resources
                total_count = 0
                for parent in parent_resources:
                    # Extract the parent key value
                    if isinstance(parent, dict) and parent_key in parent:
                        parent_key_value = parent[parent_key]
                        
                        # Handle different child API patterns based on service
                        if service == 'connectcases':
                            if api_name == 'list_fields':
                                child_params = {'domainId': parent_key_value}
                                child_result_key = 'fields'
                            elif api_name == 'list_templates':
                                child_params = {'domainId': parent_key_value}
                                child_result_key = 'templates'
                        elif service == 'customer-profiles':
                            if api_name == 'list_profile_object_types':
                                child_params = {'DomainName': parent_key_value}
                                child_result_key = 'Items'
                        elif service == 'voice-id':
                            if api_name == 'list_speakers':
                                child_params = {'DomainId': parent_key_value}
                                child_result_key = 'SpeakerSummaries'
                            elif api_name == 'list_fraudsters':
                                child_params = {'DomainId': parent_key_value}
                                child_result_key = 'FraudsterSummaries'
                        elif service == 'wisdom':
                            if api_name == 'list_content':
                                child_params = {'knowledgeBaseId': parent_key_value}
                                child_result_key = 'contentSummaries'
                        
                        # Count child resources
                        child_count = self._count_via_pagination(client, api_method, child_result_key, 
                                                             child_params, None)
                        if child_count and 'current_value' in child_count:
                            total_count += child_count['current_value']
                
                return self._create_utilization_result(quota, total_count)
                
            # Method 3: CloudWatch metrics for real-time usage
            elif method == 'cloudwatch':
                metric_name = metric_config.get('metric_name')
                statistic = metric_config.get('statistic', 'Maximum')
                namespace = metric_config.get('namespace', 'AWS/Connect')
                
                end_time = datetime.utcnow()
                start_time = end_time - timedelta(hours=1)
                
                dimensions = [{'Name': 'InstanceId', 'Value': instance_id}]
                
                response = self.cloudwatch_client.get_metric_statistics(
                    Namespace=namespace,
                    MetricName=metric_name,
                    Dimensions=dimensions,
                    StartTime=start_time,
                    EndTime=end_time,
                    Period=300,  # 5-minute periods
                    Statistics=[statistic]
                )
                
                if 'Datapoints' in response and response['Datapoints']:
                    if statistic == 'Maximum':
                        current_value = max([dp[statistic] for dp in response['Datapoints']])
                    elif statistic == 'Average':
                        current_value = sum([dp[statistic] for dp in response['Datapoints']]) / len(response['Datapoints'])
                    elif statistic == 'Sum':
                        current_value = sum([dp[statistic] for dp in response['Datapoints']])
                    else:
                        current_value = response['Datapoints'][-1][statistic]
                        
                    return self._create_utilization_result(quota, current_value)
                else:
                    logger.warning(f"No datapoints found for {metric_name} on instance {instance_id}")
                    return self._create_utilization_result(quota, 0)
                    
            # Method 4: API usage rates via CloudWatch
            elif method == 'cloudwatch_api':
                operation = metric_config.get('operation')
                namespace = metric_config.get('namespace', 'AWS/Connect')
                
                end_time = datetime.utcnow()
                start_time = end_time - timedelta(hours=1)
                
                response = self.cloudwatch_client.get_metric_statistics(
                    Namespace=namespace,
                    MetricName='ThrottlingException',
                    Dimensions=[
                        {
                            'Name': 'ApiName',
                            'Value': operation
                        }
                    ],
                    StartTime=start_time,
                    EndTime=end_time,
                    Period=300,  # 5-minute periods
                    Statistics=['SampleCount']
                )
                
                # For API rate limits, we check throttling exceptions
                # If there are throttling exceptions, we're approaching the limit
                if 'Datapoints' in response and response['Datapoints']:
                    throttle_count = sum([dp['SampleCount'] for dp in response['Datapoints']])
                    # If throttling is occurring, estimate utilization at 90%
                    if throttle_count > 0:
                        return self._create_utilization_result(quota, quota_value * 0.9)  # Estimate at 90% if throttling
                    else:
                        # No throttling, estimate at 50% (we can't know exact usage)
                        return self._create_utilization_result(quota, quota_value * 0.5)
                else:
                    # No data points, assume low utilization
                    return self._create_utilization_result(quota, quota_value * 0.1)
                    
            # Method 5: Not directly measurable
            elif method == 'not_measurable':
                logger.info(f"Quota {quota_name} cannot be directly measured")
                return None
                
            else:
                logger.warning(f"Unknown measurement method '{method}' for quota {quota_name}")
                return None
                
        except ClientError as e:
            error_code = e.response['Error']['Code']
            error_msg = e.response['Error']['Message']
            logger.error(f"Error measuring quota {quota_name}: {error_code} - {sanitize_log(error_msg)}")
            return None
        except Exception as e:
            logger.error(f"Unexpected error measuring quota {quota_name}: {sanitize_log(str(e))}")
            return None
            
    def _count_via_pagination(self, client, api_method, result_key, params, quota):
        """Enhanced helper method to count resources via API pagination."""
        try:
            # Get all resources
            resources = self._get_all_resources_via_pagination(client, api_method, result_key, params)
            
            # Count the resources
            count = len(resources)
            
            # Create utilization result if quota is provided
            if quota:
                return self._create_utilization_result(quota, count)
            else:
                # Just return the count for internal use
                return {'current_value': count}
                
        except ClientError as e:
            error_code = e.response['Error']['Code']
            error_msg = e.response['Error']['Message']
            logger.error(f"Error in API pagination: {error_code} - {sanitize_log(error_msg)}")
            return None
            
    def _get_all_resources_via_pagination(self, client, api_method, result_key, params):
        """Helper method to get all resources via pagination."""
        resources = []
        
        try:
            # Check if the API supports pagination
            paginator_name = api_method.__name__
            if hasattr(client, 'get_paginator') and paginator_name in [p for p in client.get_available_paginators()]:
                paginator = client.get_paginator(paginator_name)
                for page in paginator.paginate(**params):
                    if result_key in page:
                        resources.extend(page[result_key])
            else:
                # Fall back to manual pagination
                response = api_method(**params)
                while True:
                    if result_key in response:
                        resources.extend(response[result_key])
                    if 'NextToken' in response and response['NextToken']:
                        params['NextToken'] = response['NextToken']
                        response = api_method(**params)
                    else:
                        break
        except Exception as e:
            logger.error(f"Error getting resources via pagination: {sanitize_log(str(e))}")
            
        return resources
        
    def _get_result_key_for_api(self, api_name):
        """Helper method to get the result key for a given API."""
        # Map of API names to their result keys
        result_key_map = {
            'list_users': 'UserSummaryList',
            'list_queues': 'QueueSummaryList',
            'list_phone_numbers': 'PhoneNumberSummaryList',
            'list_hours_of_operations': 'HoursOfOperationSummaryList',
            'list_contact_flows': 'ContactFlowSummaryList',
            'list_routing_profiles': 'RoutingProfileSummaryList',
            'list_security_profiles': 'SecurityProfileSummaryList',
            'list_quick_connects': 'QuickConnectSummaryList',
            'list_agent_statuses': 'AgentStatusSummaryList',
            'list_prompts': 'PromptSummaryList',
            'list_tasks': 'TaskSummaryList',
            'list_task_templates': 'TaskTemplates',
            'list_evaluation_forms': 'EvaluationFormSummaryList'
        }
        
        return result_key_map.get(api_name, 'Items')  # Default to 'Items' if not found
            
    def _create_utilization_result(self, quota, current_value):
        """Helper method to create a standardized utilization result."""
        quota_value = quota['Value']
        utilization_percentage = (current_value / quota_value * 100) if quota_value > 0 else 0
        
        return {
            'quota_name': quota['QuotaName'],
            'quota_code': quota['QuotaCode'],
            'quota_value': quota_value,
            'current_value': current_value,
            'utilization_percentage': utilization_percentage
        }
    
    def check_all_quotas(self):
        """Check all quotas for all Connect instances and return results."""
        results = []
        
        try:
            # Get all Connect instances
            instances = self.get_connect_instances()
            if not instances:
                logger.info("No Amazon Connect instances found in this account/region")
                return results
                
            # Get all service quotas for Connect
            quotas = self.get_service_quotas()
            if not quotas:
                logger.info("No Amazon Connect service quotas found")
                return results
                
            # For each instance, check each applicable quota
            for instance in instances:
                instance_id = instance['Id']
                instance_arn = instance['Arn']
                instance_name = instance.get('InstanceAlias', 'Unknown')
                
                logger.info(f"Checking quotas for instance: {instance_name} ({instance_id})")
                
                # Check if this is a custom CXP implementation
                is_custom_cxp = False
                try:
                    # Check for custom CXP indicators (e.g., custom contact flows)
                    contact_flows = self.connect_client.list_contact_flows(
                        InstanceId=instance_id,
                        ContactFlowTypes=['CUSTOMER_QUEUE', 'CUSTOMER_HOLD', 'CUSTOMER_WHISPER']
                    )
                    if len(contact_flows.get('ContactFlowSummaryList', [])) > 0:
                        is_custom_cxp = True
                        logger.info(f"Instance {instance_name} appears to be a custom CXP implementation")
                except ClientError:
                    # If we can't determine, assume it's not custom
                    pass
                
                # Track instance-level metrics
                instance_metrics = {
                    'instance_id': instance_id,
                    'instance_name': instance_name,
                    'instance_arn': instance_arn,
                    'is_custom_cxp': is_custom_cxp,
                    'region': self.region,
                    'quotas': [],
                    'timestamp': datetime.utcnow().isoformat()
                }
                
                # Check each quota for this instance
                for quota in quotas:
                    utilization = self.get_quota_utilization(instance_id, quota)
                    if utilization:
                        # Add security context
                        utilization['execution_id'] = EXECUTION_ID
                        utilization['timestamp'] = datetime.utcnow().isoformat()
                        
                        # Check if utilization exceeds threshold
                        if utilization['utilization_percentage'] >= THRESHOLD_PERCENTAGE:
                            logger.warning(
                                f"ALERT: {utilization['quota_name']} at "
                                f"{utilization['utilization_percentage']:.1f}% of limit "
                                f"({utilization['current_value']}/{utilization['quota_value']}) "
                                f"for instance {instance_name}"
                            )
                            
                            # Add to results
                            results.append({
                                'instance_id': instance_id,
                                'instance_name': instance_name,
                                'quota_info': utilization,
                                'exceeds_threshold': True,
                                'is_custom_cxp': is_custom_cxp
                            })
                        else:
                            # Add to results without alert
                            results.append({
                                'instance_id': instance_id,
                                'instance_name': instance_name,
                                'quota_info': utilization,
                                'exceeds_threshold': False,
                                'is_custom_cxp': is_custom_cxp
                            })
                            
                        # Add to instance metrics
                        instance_metrics['quotas'].append(utilization)
                
                # Save instance metrics to a separate file for historical tracking
                self._save_instance_metrics(instance_metrics)
            
            return results
            
        except Exception as e:
            logger.error(f"Error checking quotas: {sanitize_log(str(e))}")
            return results
            
    def _save_instance_metrics(self, instance_metrics):
        """Save instance metrics for historical tracking using configured storage."""
        try:
            instance_id = instance_metrics['instance_id']
            instance_name = instance_metrics['instance_name']
            current_date = datetime.utcnow().strftime('%Y%m%d')
            timestamp_iso = datetime.utcnow().isoformat()
            
            # Generate a unique ID for this metric record
            record_id = f"{instance_id}_{str(uuid.uuid4())[:8]}"
            
            # Add execution ID and timestamp to metrics
            instance_metrics['execution_id'] = EXECUTION_ID
            instance_metrics['timestamp_iso'] = timestamp_iso
            
            # Option 1: Save to S3 if configured
            if self.s3_client and self.s3_bucket:
                # Path format: connect-metrics/YYYY-MM-DD/instance_id/timestamp.json
                s3_key = f"connect-metrics/{current_date}/{instance_id}/{datetime.utcnow().strftime('%H%M%S')}.json"
                
                try:
                    # Convert to JSON and upload to S3
                    json_data = json.dumps(instance_metrics, default=str)
                    self.s3_client.put_object(
                        Bucket=self.s3_bucket,
                        Key=s3_key,
                        Body=json_data,
                        ContentType='application/json'
                    )
                    logger.info(f"Saved metrics for instance {instance_name} to S3: s3://{self.s3_bucket}/{s3_key}")
                    
                    # Also save to a latest file for easy access to most recent data
                    latest_key = f"connect-metrics/latest/{instance_id}.json"
                    self.s3_client.put_object(
                        Bucket=self.s3_bucket,
                        Key=latest_key,
                        Body=json_data,
                        ContentType='application/json'
                    )
                    
                except ClientError as e:
                    logger.error(f"Error saving to S3: {sanitize_log(str(e))}")
            
            # Option 2: Save to DynamoDB if configured
            elif self.use_dynamodb and self.dynamodb_client and self.dynamodb_table:
                try:
                    # Prepare item for DynamoDB
                    # Convert complex types to strings for DynamoDB
                    item = {
                        'id': {'S': record_id},
                        'timestamp': {'S': timestamp_iso},
                        'execution_id': {'S': EXECUTION_ID},
                        'instance_id': {'S': instance_id},
                        'instance_name': {'S': instance_name},
                        'region': {'S': self.region},
                        'is_custom_cxp': {'BOOL': instance_metrics.get('is_custom_cxp', False)},
                        'data': {'S': json.dumps(instance_metrics, default=str)}
                    }
                    
                    # Add quota summary attributes for easier querying
                    for quota in instance_metrics.get('quotas', []):
                        quota_code = quota.get('quota_code', '')
                        if quota_code:
                            # Store utilization percentage for each quota code
                            item[f'quota_{quota_code}'] = {
                                'N': str(quota.get('utilization_percentage', 0))
                            }
                    
                    # Put item in DynamoDB
                    self.dynamodb_client.put_item(
                        TableName=self.dynamodb_table,
                        Item=item
                    )
                    
                    logger.info(f"Saved metrics for instance {instance_name} to DynamoDB table {self.dynamodb_table}")
                    
                except ClientError as e:
                    logger.error(f"Error saving to DynamoDB: {sanitize_log(str(e))}")
            
            # Option 3: Fall back to local file storage
            else:
                # Create metrics directory if it doesn't exist
                os.makedirs('metrics', exist_ok=True)
                
                # Create a file for this instance
                filename = f"metrics/connect_metrics_{instance_id}_{current_date}.json"
                
                # Append to existing file or create new one
                if os.path.exists(filename):
                    with open(filename, 'r') as f:
                        try:
                            existing_data = json.load(f)
                            if not isinstance(existing_data, list):
                                existing_data = [existing_data]
                        except json.JSONDecodeError:
                            existing_data = []
                    existing_data.append(instance_metrics)
                    with open(filename, 'w') as f:
                        json.dump(existing_data, f, indent=2, default=str)
                else:
                    with open(filename, 'w') as f:
                        json.dump([instance_metrics], f, indent=2, default=str)
                        
                logger.info(f"Saved metrics for instance {instance_name} to local file {filename}")
            
        except Exception as e:
            logger.error(f"Error saving instance metrics: {sanitize_log(str(e))}")
            # Continue execution even if metrics saving fails
    
    def send_alert(self, topic_arn, quota_info):
        """Send an SNS alert for a quota that exceeds the threshold."""
        try:
            # Validate SNS topic ARN format
            if not topic_arn.startswith('arn:aws:sns:'):
                logger.error(f"Invalid SNS topic ARN format: {sanitize_log(topic_arn)}")
                return False
                
            # Create a structured message with all relevant information
            message_dict = {
                "alert_type": "CONNECT_QUOTA_THRESHOLD_EXCEEDED",
                "severity": "WARNING",
                "timestamp": datetime.utcnow().isoformat(),
                "execution_id": EXECUTION_ID,
                "details": {
                    "instance_name": quota_info['instance_name'],
                    "instance_id": quota_info['instance_id'],
                    "is_custom_cxp": quota_info.get('is_custom_cxp', False),
                    "quota_name": quota_info['quota_info']['quota_name'],
                    "quota_code": quota_info['quota_info']['quota_code'],
                    "current_usage": quota_info['quota_info']['current_value'],
                    "quota_limit": quota_info['quota_info']['quota_value'],
                    "utilization_percentage": quota_info['quota_info']['utilization_percentage'],
                    "threshold_percentage": THRESHOLD_PERCENTAGE,
                    "region": self.region
                },
                "recommended_actions": [
                    "Review current Connect usage patterns",
                    "Consider requesting a service quota increase if needed",
                    "Optimize resource usage if possible"
                ]
            }
            
            # Human-readable message
            human_message = (
                f"ALERT: Amazon Connect Service Quota Threshold Exceeded\n\n"
                f"Instance: {quota_info['instance_name']} ({quota_info['instance_id']})\n"
                f"Quota: {quota_info['quota_info']['quota_name']}\n"
                f"Current Usage: {quota_info['quota_info']['current_value']}\n"
                f"Quota Limit: {quota_info['quota_info']['quota_value']}\n"
                f"Utilization: {quota_info['quota_info']['utilization_percentage']:.1f}%\n"
                f"Threshold: {THRESHOLD_PERCENTAGE}%\n\n"
                f"Please take appropriate action to avoid service disruption."
            )
            
            # Send both structured JSON and human-readable message
            self.sns_client.publish(
                TopicArn=topic_arn,
                Message=json.dumps({
                    "default": human_message,
                    "email": human_message,
                    "sms": f"Connect Alert: {quota_info['quota_info']['quota_name']} at {quota_info['quota_info']['utilization_percentage']:.1f}%",
                    "json": json.dumps(message_dict)
                }),
                Subject=f"Connect Quota Alert: {quota_info['quota_info']['quota_name']} at {quota_info['quota_info']['utilization_percentage']:.1f}%",
                MessageStructure='json'
            )
            
            logger.info(f"Alert sent to {sanitize_log(topic_arn)}")
            return True
            
        except ClientError as e:
            error_code = e.response['Error']['Code']
            error_msg = e.response['Error']['Message']
            logger.error(f"Failed to send SNS alert: {error_code} - {sanitize_log(error_msg)}")
            return False
        except Exception as e:
            logger.error(f"Unexpected error sending alert: {sanitize_log(str(e))}")
            return False

def validate_sns_topic(sns_client, topic_arn):
    """Validate that the SNS topic exists and is accessible."""
    if not topic_arn:
        return False
        
    try:
        sns_client.get_topic_attributes(TopicArn=topic_arn)
        return True
    except ClientError as e:
        error_code = e.response['Error']['Code']
        logger.error(f"SNS topic validation failed: {error_code}")
        return False

def save_report_to_s3(s3_client, bucket, report_data):
    """Save report data to S3 bucket."""
    try:
        # Generate keys for the report
        timestamp = datetime.utcnow().strftime('%Y%m%d_%H%M%S')
        date_prefix = datetime.utcnow().strftime('%Y/%m/%d')
        report_key = f"connect-reports/{date_prefix}/connect_quota_report_{timestamp}.json"
        latest_key = "connect-reports/latest/connect_quota_report.json"
        
        # Convert to JSON
        json_data = json.dumps(report_data, default=str)
        
        # Upload timestamped report
        s3_client.put_object(
            Bucket=bucket,
            Key=report_key,
            Body=json_data,
            ContentType='application/json'
        )
        
        # Upload to latest location for easy access
        s3_client.put_object(
            Bucket=bucket,
            Key=latest_key,
            Body=json_data,
            ContentType='application/json'
        )
        
        logger.info(f"Report saved to S3: s3://{bucket}/{report_key}")
        return f"s3://{bucket}/{report_key}"
        
    except ClientError as e:
        logger.error(f"Error saving report to S3: {sanitize_log(str(e))}")
        return None

def save_report_to_dynamodb(dynamodb_client, table_name, report_data):
    """Save report summary to DynamoDB table."""
    try:
        # Create a summary item for this execution
        timestamp = datetime.utcnow().isoformat()
        
        # Basic attributes
        item = {
            'id': {'S': f"report_{EXECUTION_ID}"},
            'timestamp': {'S': timestamp},
            'execution_id': {'S': EXECUTION_ID},
            'region': {'S': report_data.get('region', 'unknown')},
            'threshold_percentage': {'N': str(report_data.get('threshold_percentage', 80))},
            'alert_count': {'N': str(report_data.get('alert_count', 0))},
            'instance_count': {'N': str(len(set([r.get('instance_id') for r in report_data.get('results', [])])))}
        }
        
        # Add summary of alerts
        alerts = []
        for result in report_data.get('results', []):
            if result.get('exceeds_threshold', False):
                alerts.append({
                    'instance_id': result.get('instance_id', 'unknown'),
                    'instance_name': result.get('instance_name', 'unknown'),
                    'quota_name': result.get('quota_info', {}).get('quota_name', 'unknown'),
                    'utilization': result.get('quota_info', {}).get('utilization_percentage', 0)
                })
        
        if alerts:
            item['alerts'] = {'S': json.dumps(alerts, default=str)}
        
        # Store full report data as a compressed JSON string
        item['report_data'] = {'S': json.dumps(report_data, default=str)}
        
        # Put item in DynamoDB
        dynamodb_client.put_item(
            TableName=table_name,
            Item=item
        )
        
        logger.info(f"Report summary saved to DynamoDB table {table_name}")
        return True
        
    except ClientError as e:
        logger.error(f"Error saving report to DynamoDB: {sanitize_log(str(e))}")
        return False

def main():
    """Main function to run the quota monitor."""
    try:
        # Log execution start with unique ID for traceability
        logger.info(f"Starting Connect Quota Monitor execution {EXECUTION_ID}")
        
        # Get configuration from environment or use defaults
        region = os.environ.get('AWS_REGION')
        profile = os.environ.get('AWS_PROFILE')
        sns_topic_arn = os.environ.get('ALERT_SNS_TOPIC_ARN')
        custom_threshold = os.environ.get('THRESHOLD_PERCENTAGE')
        s3_bucket = os.environ.get('S3_BUCKET')
        use_dynamodb = os.environ.get('USE_DYNAMODB', 'false').lower() == 'true'
        dynamodb_table = os.environ.get('DYNAMODB_TABLE', 'ConnectQuotaMonitor')
        
        # Validate threshold if provided
        threshold = THRESHOLD_PERCENTAGE
        if custom_threshold:
            try:
                threshold_value = int(custom_threshold)
                if 1 <= threshold_value <= 99:
                    threshold = threshold_value
                else:
                    logger.warning(f"Invalid threshold value {threshold_value}, must be between 1-99. Using default {THRESHOLD_PERCENTAGE}%")
            except ValueError:
                logger.warning(f"Invalid threshold format: {custom_threshold}. Using default {THRESHOLD_PERCENTAGE}%")
        
        # Initialize the monitor with proper error handling
        try:
            monitor = ConnectQuotaMonitor(
                region_name=region, 
                profile_name=profile,
                s3_bucket=s3_bucket,
                use_dynamodb=use_dynamodb,
                dynamodb_table=dynamodb_table
            )
        except Exception as e:
            logger.error(f"Failed to initialize ConnectQuotaMonitor: {sanitize_log(str(e))}")
            sys.exit(1)
        
        # Validate SNS topic if provided
        if sns_topic_arn:
            if not validate_sns_topic(monitor.sns_client, sns_topic_arn):
                logger.warning(f"SNS topic validation failed for {sanitize_log(sns_topic_arn)}. Alerts will not be sent.")
                sns_topic_arn = None
        
        # Check all quotas with proper error handling
        try:
            results = monitor.check_all_quotas()
        except Exception as e:
            logger.error(f"Failed to check quotas: {sanitize_log(str(e))}")
            sys.exit(1)
        
        # Print summary with secure output handling
        print(f"\nConnect Service Quota Utilization Summary:")
        print(f"{'Instance':<20} {'Quota':<40} {'Usage':<10} {'Limit':<10} {'Utilization':<10}")
        print("-" * 90)
        
        alert_count = 0
        for result in results:
            quota_info = result['quota_info']
            
            # Safely handle potential missing keys
            instance_name = result.get('instance_name', 'Unknown')[:20]
            quota_name = quota_info.get('quota_name', 'Unknown')[:40]
            current_value = quota_info.get('current_value', 0)
            quota_value = quota_info.get('quota_value', 0)
            utilization = quota_info.get('utilization_percentage', 0)
            
            try:
                print(
                    f"{instance_name:<20} "
                    f"{quota_name:<40} "
                    f"{current_value:<10.1f} "
                    f"{quota_value:<10.1f} "
                    f"{utilization:.1f}%"
                )
            except Exception as e:
                logger.error(f"Error printing result: {sanitize_log(str(e))}")
            
            # Send alerts for quotas exceeding threshold
            if result.get('exceeds_threshold', False) and sns_topic_arn:
                if monitor.send_alert(sns_topic_arn, result):
                    alert_count += 1
        
        # Add metadata to results
        report_data = {
            'execution_id': EXECUTION_ID,
            'timestamp': datetime.utcnow().isoformat(),
            'region': region or 'default',
            'threshold_percentage': threshold,
            'results': results,
            'alert_count': alert_count
        }
        
        # Option 1: Save to S3 if configured
        report_location = None
        if s3_bucket and monitor.s3_client:
            report_location = save_report_to_s3(monitor.s3_client, s3_bucket, report_data)
            print(f"\nDetailed report saved to {report_location}")
            
        # Option 2: Save to DynamoDB if configured
        if use_dynamodb and monitor.dynamodb_client and dynamodb_table:
            save_report_to_dynamodb(monitor.dynamodb_client, dynamodb_table, report_data)
            print(f"\nReport summary saved to DynamoDB table {dynamodb_table}")
            
        # Option 3: Fall back to local file storage
        if not report_location:
            # Create reports directory if it doesn't exist
            os.makedirs('reports', exist_ok=True)
            
            # Save results to file with timestamp for historical tracking
            timestamp = datetime.utcnow().strftime('%Y%m%d_%H%M%S')
            report_file = f'reports/connect_quota_report_{timestamp}.json'
            
            with open(report_file, 'w') as f:
                json.dump(report_data, f, indent=2, default=str)
            
            # Also save to the standard location for backward compatibility
            with open('connect_quota_report.json', 'w') as f:
                json.dump(report_data, f, indent=2, default=str)
            
            print(f"\nDetailed report saved to {report_file}")
        
        if alert_count > 0:
            print(f"\nWARNING: {alert_count} quotas exceeded the {threshold}% threshold!")
            
        # Log execution completion
        logger.info(f"Connect Quota Monitor execution {EXECUTION_ID} completed successfully")
        
    except Exception as e:
        logger.error(f"Unhandled exception in main: {sanitize_log(str(e))}")
        sys.exit(1)

if __name__ == "__main__":
    main()

def main(event=None, context=None):
    """
    Main Lambda handler function
    """
    try:
        # Get environment variables
        threshold = int(os.environ.get('THRESHOLD_PERCENTAGE', '80'))
        sns_topic_arn = os.environ.get('ALERT_SNS_TOPIC_ARN')
        s3_bucket = os.environ.get('S3_BUCKET', '')
        use_dynamodb = os.environ.get('USE_DYNAMODB', 'false').lower() == 'true'
        dynamodb_table = os.environ.get('DYNAMODB_TABLE', 'ConnectQuotaMonitor')
        
        logger.info(f"Starting Connect Quota Monitor execution {EXECUTION_ID}")
        logger.info(f"Configuration: threshold={threshold}%, SNS={bool(sns_topic_arn)}, S3={bool(s3_bucket)}, DynamoDB={use_dynamodb}")
        
        # Initialize the monitor
        monitor = ConnectQuotaMonitor(sns_topic_arn=sns_topic_arn)
        
        # Get all Connect instances
        instances = monitor.get_connect_instances()
        if not instances:
            logger.warning("No Connect instances found in this region")
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'No Connect instances found',
                    'execution_id': EXECUTION_ID
                })
            }
        
        logger.info(f"Found {len(instances)} Connect instance(s)")
        
        # Monitor quotas for all instances
        all_results = []
        alert_count = 0
        
        for instance in instances:
            instance_id = instance['Id']
            instance_name = instance.get('InstanceAlias', instance_id)
            
            logger.info(f"Monitoring quotas for instance: {instance_name} ({instance_id})")
            
            # Get quota utilization for this instance
            results = monitor.check_quota_utilization(instance_id, threshold)
            
            # Add instance info to results
            for result in results:
                result['instance_id'] = instance_id
                result['instance_name'] = instance_name
                all_results.append(result)
                
                if result['utilization_percentage'] >= threshold:
                    alert_count += 1
        
        # Prepare report data
        report_data = {
            'execution_id': EXECUTION_ID,
            'timestamp': datetime.utcnow().isoformat(),
            'threshold_percentage': threshold,
            'instances_monitored': len(instances),
            'total_quotas_checked': len(all_results),
            'quotas_above_threshold': alert_count,
            'results': all_results,
            'alert_count': alert_count
        }
        
        # Save to S3 if configured
        if s3_bucket and monitor.s3_client:
            report_location = save_report_to_s3(monitor.s3_client, s3_bucket, report_data)
            logger.info(f"Report saved to S3: {report_location}")
            
        # Save to DynamoDB if configured
        if use_dynamodb and monitor.dynamodb_client and dynamodb_table:
            save_report_to_dynamodb(monitor.dynamodb_client, dynamodb_table, report_data)
            logger.info(f"Report saved to DynamoDB: {dynamodb_table}")
        
        logger.info(f"Connect Quota Monitor execution {EXECUTION_ID} completed successfully")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Quota monitoring completed successfully',
                'execution_id': EXECUTION_ID,
                'instances_monitored': len(instances),
                'quotas_checked': len(all_results),
                'alerts_triggered': alert_count,
                'threshold_percentage': threshold
            })
        }
        
    except Exception as e:
        error_msg = f"Error in Lambda handler: {sanitize_log(str(e))}"
        logger.error(error_msg)
        
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': 'Internal server error',
                'execution_id': EXECUTION_ID,
                'message': 'Check CloudWatch logs for details'
            })
        }

# Lambda handler alias for AWS Lambda
lambda_handler = main