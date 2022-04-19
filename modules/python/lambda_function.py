import base64
import boto3
import gzip
import json
import logging
import os

from botocore.exceptions import ClientError

logging.basicConfig(level=logging.INFO)
LOGGER = logging.getLogger(__name__)

EMAIL_SUBJECT_PREFIX = os.environ['EMAIL_SUBJECT_PREFIX']
SNS_TOPIC_ARN = os.environ['LOG_NOTIFIER_SNS_TOPIC_ARN']
SNS_CLIENT = boto3.client('sns')


def extract_log_payload(event):
    LOGGER.setLevel(logging.DEBUG)
    LOGGER.debug(event['awslogs']['data'])
    compressed_payload = base64.b64decode(event['awslogs']['data'])
    uncompressed_payload = gzip.decompress(compressed_payload)
    log_payload = json.loads(uncompressed_payload)
    return log_payload


def collect_details(payload):
    message = ""
    log_events = payload['logEvents']
    LOGGER.debug(payload)
    log_group_name = payload['logGroup']
    log_stream_name = payload['logStream']
    component_name = log_group_name.split('/')
    LOGGER.debug(f"Log group: {log_group_name}")
    LOGGER.debug(f"Log stream: {log_stream_name}")
    LOGGER.debug(f"Component name: {component_name[3]}")
    LOGGER.debug(log_events)
    for log_event in log_events:
        message += log_event['message']
    LOGGER.debug('Message: %s' % message.split("\n"))
    return log_group_name, log_stream_name, message, component_name


def publish_message(log_group, logstream, message, component_name):
    try:
        message = ""
        message += "\nSummary" + "\n\n"
        message += "##########################################################\n"
        message += "# Log group name: " + str(log_group) + "\n"
        message += "# Log stream: " + str(logstream) + "\n"
        message += "# Log message: " + "\n"
        message += "# \t\t" + str(message.split("\n")) + "\n"
        message += "##########################################################\n"
        SNS_CLIENT.publish(
            TargetArn=SNS_TOPIC_ARN,
            Subject=f"[{EMAIL_SUBJECT_PREFIX}] Notice for {component_name[3]}",
            Message=message
        )
    except ClientError as e:
        LOGGER.error("An error occurred: %s" % e)


def lambda_handler(event, context):
    log_payload = extract_log_payload(event)
    log_group_name, log_stream_name, message, component_name = collect_details(log_payload)
    publish_message(log_group_name, log_stream_name, message, component_name)
