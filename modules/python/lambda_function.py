"""Forwards matching CloudWatch Logs events as one readable e-mail per batch.

The subscription filter decides which lines reach this function. Here, lines
matching one of EXCLUDE_PATTERNS are dropped, the rest is grouped by a
normalised fingerprint, and a fingerprint that was already reported for the
same log group within DEDUP_WINDOW_SECONDS does not trigger another e-mail.
The state lives in a DynamoDB table with TTL (DEDUP_TABLE_NAME); without it,
every batch with matching lines sends one e-mail.
"""

import base64
import gzip
import hashlib
import json
import logging
import os
import re
import time
from datetime import datetime, timezone
from urllib.parse import quote

import boto3
from botocore.exceptions import BotoCoreError, ClientError

LOGGER = logging.getLogger()
LOGGER.setLevel(logging.INFO)

EMAIL_SUBJECT_PREFIX = os.environ['EMAIL_SUBJECT_PREFIX']
SNS_TOPIC_ARN = os.environ['LOG_NOTIFIER_SNS_TOPIC_ARN']
EXCLUDE_PATTERNS = [re.compile(p) for p in json.loads(os.environ.get('EXCLUDE_PATTERNS') or '[]')]
DEDUP_TABLE_NAME = os.environ.get('DEDUP_TABLE_NAME', '')
DEDUP_WINDOW_SECONDS = int(os.environ.get('DEDUP_WINDOW_SECONDS') or '0')
MAX_SAMPLE_LINES = int(os.environ.get('MAX_SAMPLE_LINES') or '20')
REGION = os.environ.get('AWS_REGION', 'eu-west-1')

SNS_CLIENT = boto3.client('sns')
DYNAMODB_CLIENT = boto3.client('dynamodb') if DEDUP_TABLE_NAME and DEDUP_WINDOW_SECONDS > 0 else None

# SNS accepts messages of up to 256 KB and subjects of up to 100 characters.
# A single log event, e.g. a logged query with thousands of parameters, can be
# larger than that on its own.
MAX_EVENT_LENGTH = 4000
MAX_MESSAGE_BYTES = 200 * 1024
MAX_SUBJECT_LENGTH = 100

# Parts of a line that differ between otherwise identical messages.
_VOLATILE = [
    (re.compile(r'\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}(?:[.,]\d+)?(?:Z|[+-]\d{2}:?\d{2})?'), '<time>'),
    (re.compile(r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'), '<id>'),
    (re.compile(r'\b[0-9a-fA-F]{8,}\b'), '<hex>'),
    (re.compile(r'\d+'), '#'),
    (re.compile(r'\s+'), ' '),
]


def shorten(text, limit):
    if len(text) <= limit:
        return text
    return text[:limit] + f" ... ({len(text) - limit} more characters)"


def extract_log_payload(event):
    compressed_payload = base64.b64decode(event['awslogs']['data'])
    return json.loads(gzip.decompress(compressed_payload))


def is_excluded(message):
    return any(pattern.search(message) for pattern in EXCLUDE_PATTERNS)


def fingerprint(message):
    text = message[:1000]
    for pattern, replacement in _VOLATILE:
        text = pattern.sub(replacement, text)
    return hashlib.sha1(text.strip()[:300].encode('utf-8')).hexdigest()


def group_events(log_events):
    """Returns {fingerprint: [events]} in order of first appearance."""
    groups = {}
    for log_event in log_events:
        groups.setdefault(fingerprint(log_event['message']), []).append(log_event)
    return groups


def claim(log_group, key, count, now):
    """Records a fingerprint. Returns (is_new, suppressed_since_last_mail).

    A fingerprint is new when there is no record or its window has passed;
    then the record restarts the window. Otherwise the occurrences are added
    to the record and the lines are not mailed again. Errors fail open.
    """
    if DYNAMODB_CLIENT is None:
        return True, 0
    item_key = {'pk': {'S': f"{log_group}#{key}"}}
    try:
        old = DYNAMODB_CLIENT.put_item(
            TableName=DEDUP_TABLE_NAME,
            Item={
                **item_key,
                'window_end': {'N': str(now + DEDUP_WINDOW_SECONDS)},
                'expires_at': {'N': str(now + 2 * DEDUP_WINDOW_SECONDS + 86400)},
                'suppressed': {'N': '0'},
            },
            ConditionExpression='attribute_not_exists(pk) OR window_end <= :now',
            ExpressionAttributeValues={':now': {'N': str(now)}},
            ReturnValues='ALL_OLD',
        ).get('Attributes', {})
        return True, int(old.get('suppressed', {}).get('N', '0'))
    except ClientError as error:
        if error.response['Error']['Code'] != 'ConditionalCheckFailedException':
            LOGGER.warning("De-duplication unavailable, sending anyway: %s", error)
            return True, 0
    except BotoCoreError as error:
        LOGGER.warning("De-duplication unavailable, sending anyway: %s", error)
        return True, 0
    try:
        DYNAMODB_CLIENT.update_item(
            TableName=DEDUP_TABLE_NAME,
            Key=item_key,
            UpdateExpression='ADD suppressed :count',
            ExpressionAttributeValues={':count': {'N': str(count)}},
        )
    except (ClientError, BotoCoreError) as error:
        LOGGER.warning("Could not count suppressed lines: %s", error)
    return False, 0


def format_time(timestamp_ms):
    return datetime.fromtimestamp(timestamp_ms / 1000, tz=timezone.utc).strftime('%Y-%m-%d %H:%M:%S UTC')


def console_link(log_group, log_stream=None):
    def encode(value):
        return quote(quote(value, safe=''), safe='').replace('%', '$')

    link = (f"https://{REGION}.console.aws.amazon.com/cloudwatch/home?region={REGION}"
            f"#logsV2:log-groups/log-group/{encode(log_group)}")
    if log_stream:
        link += f"/log-events/{encode(log_stream)}"
    return link


def component_of(log_group):
    parts = [part for part in log_group.split('/') if part]
    return parts[-1] if parts else log_group


def build_message(log_group, log_stream, groups, new_keys, suppressed_before):
    events = [e for key in groups for e in groups[key]]
    timestamps = [e['timestamp'] for e in events]
    summary = f"Matching lines in this batch: {len(events)} ({len(groups)} distinct"
    if DYNAMODB_CLIENT is not None:
        summary += f", {len(new_keys)} not reported within the last {DEDUP_WINDOW_SECONDS // 60} minutes"
    lines = [
        f"Log group:  {log_group}",
        f"Log stream: {log_stream}",
        summary + ")",
        f"First: {format_time(min(timestamps))}",
        f"Last:  {format_time(max(timestamps))}",
    ]
    if suppressed_before:
        lines.append(f"Identical lines suppressed since the previous e-mail: {suppressed_before}")
    lines += [f"Log stream in the console: {console_link(log_group, log_stream)}", "", "Sample lines:", ""]

    # One sample per distinct message first (new ones first), then further lines.
    ordered = sorted(groups, key=lambda key: key not in new_keys)
    samples = [(len(groups[key]), groups[key][0]) for key in ordered]
    samples += [(1, e) for key in ordered for e in groups[key][1:]]
    for count, log_event in samples[:MAX_SAMPLE_LINES]:
        prefix = f"[{format_time(log_event['timestamp'])}]" + (f" ({count} similar lines)" if count > 1 else "")
        lines.append(f"{prefix} {shorten(log_event['message'].rstrip(), MAX_EVENT_LENGTH)}")
        lines.append("")
    if len(samples) > MAX_SAMPLE_LINES:
        lines.append(f"... {len(samples) - MAX_SAMPLE_LINES} more lines, see the log stream.")

    message = "\n".join(lines)
    encoded = message.encode('utf-8')
    if len(encoded) > MAX_MESSAGE_BYTES:
        message = encoded[:MAX_MESSAGE_BYTES].decode('utf-8', 'ignore') + "\n... (message shortened)\n"
    return message


def build_subject(component, count):
    subject = f"[{EMAIL_SUBJECT_PREFIX}] {count} error line{'s' if count != 1 else ''} in {component}"
    subject = ''.join(c if c.isprintable() else ' ' for c in subject)
    return subject[:MAX_SUBJECT_LENGTH]


def lambda_handler(event, context):
    payload = extract_log_payload(event)
    if payload.get('messageType') != 'DATA_MESSAGE':
        return {'sent': False, 'reason': 'control message'}

    log_group = payload['logGroup']
    log_stream = payload['logStream']
    log_events = [e for e in payload['logEvents'] if not is_excluded(e['message'])]
    excluded = len(payload['logEvents']) - len(log_events)
    if not log_events:
        LOGGER.info("All %d lines excluded", excluded)
        return {'sent': False, 'reason': 'excluded', 'excluded': excluded}

    groups = group_events(log_events)
    now = int(time.time())
    new_keys = set()
    suppressed_before = 0
    for key, events in groups.items():
        is_new, suppressed = claim(log_group, key, len(events), now)
        if is_new:
            new_keys.add(key)
            suppressed_before += suppressed

    if not new_keys:
        LOGGER.info("Suppressed %d lines (%d distinct) of %s, already reported",
                    len(log_events), len(groups), log_group)
        return {'sent': False, 'reason': 'duplicate', 'lines': len(log_events)}

    message = build_message(log_group, log_stream, groups, new_keys, suppressed_before)
    SNS_CLIENT.publish(
        TargetArn=SNS_TOPIC_ARN,
        Subject=build_subject(component_of(log_group), len(log_events)),
        Message=message,
    )
    LOGGER.info("Sent %d lines (%d new distinct, %d excluded) of %s",
                len(log_events), len(new_keys), excluded, log_group)
    return {'sent': True, 'lines': len(log_events), 'new': len(new_keys), 'excluded': excluded}
