import json
import os
import logging
import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ecs_client = boto3.client('ecs')

CLUSTER = os.environ['ECS_CLUSTER_ARN']
TASK_DEF = os.environ['TASK_DEFINITION_ARN']
SUBNETS = os.environ['SUBNETS'].split(',')
SECURITY_GROUP = os.environ['SECURITY_GROUP']
DYNAMODB_TABLE = os.environ['DYNAMODB_TABLE']


def lambda_handler(event, context):
    logger.info("Received event: %s", json.dumps(event))
    try:
        record = event['Records'][0]
        bucket = record['s3']['bucket']['name']
        key = record['s3']['object']['key']

        response = ecs_client.run_task(
            cluster=CLUSTER,
            taskDefinition=TASK_DEF,
            launchType='FARGATE',
            networkConfiguration={
                'awsvpcConfiguration': {
                    'subnets': SUBNETS,
                    'securityGroups': [SECURITY_GROUP],
                    'assignPublicIp': 'ENABLED'
                }
            },
            overrides={
                'containerOverrides': [{
                    'name': 'transaction-processor',
                    'environment': [
                        {'name': 'S3_BUCKET', 'value': bucket},
                        {'name': 'S3_KEY', 'value': key},
                        {'name': 'DYNAMODB_TABLE', 'value': DYNAMODB_TABLE}
                    ]
                }]
            }
        )

        logger.info("RunTask response: %s", response)
        return {'statusCode': 200, 'body': json.dumps({'message': 'Task started'})}
    except Exception as e:
        logger.error("Error starting task: %s", e)
        return {'statusCode': 500, 'body': str(e)}
