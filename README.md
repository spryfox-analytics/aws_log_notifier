# aws_log_notifier

Terraform module that e-mails error lines of a CloudWatch Logs log group. A subscription filter
forwards matching lines to a small Python Lambda, which groups them and publishes one message per
batch to an SNS topic with an e-mail subscription.

```hcl
module "api_error_notifier" {
  source = "git::https://github.com/spryfox-analytics/aws_log_notifier.git?ref=v3.2.0"

  application                = "my-app"
  customer                   = "my-customer"
  project                    = "my-project"
  aws_region                 = "eu-west-1"
  camel_case_name_prefix     = "MyAppApi"
  kebab_case_name_prefix     = "my-app-api-"
  email_subject_prefix       = "my-app-dev"
  log_group_arn              = aws_cloudwatch_log_group.api.arn
  log_group_name             = aws_cloudwatch_log_group.api.name
  log_receiver_email_address = "alerts@example.com"
  log_retention_in_days      = 30

  # Optional
  exclude_patterns        = ["database not reachable"]
  dedup_window_in_minutes = 60
}
```

## What gets mailed

**Filter.** Without `filter_pattern`, the subscription matches log levels and runtime failures,
not every line that contains "error":

- level markers: `<tab>ERROR<tab>` (Lambda text logs), `[ERROR]`, ` ERROR `, `ERROR:`, the same
  for `CRITICAL` and `FATAL`, and JSON fields such as `"level":"ERROR"`, `"level": "error"`,
  `"levelname":"ERROR"`;
- `Traceback (most recent call last)` (uncaught Python exceptions);
- Lambda runtime failures: `Task timed out`, `Runtime exited`, `Process exited before completing`,
  `Runtime.ImportModuleError`, `Runtime.HandlerNotFound`, `Runtime.UserCodeSyntaxError`.

A WARN or DEBUG line that only mentions a class such as `PrismaClientInitializationError` no longer
triggers an e-mail. CloudWatch Logs matches the terms as case-sensitive substrings. The output
`default_filter_pattern` holds the pattern, so a caller can extend it:

```hcl
filter_pattern = "${module.x.default_filter_pattern} ?\"Out of memory\""
```

Up to v3.1.0 the default was `?ERROR ?Error ?error`; set it explicitly to keep the old behaviour.

**Exclusions.** `exclude_patterns` takes Python regular expressions. Matching lines are dropped in
the Lambda before anything else, e.g. expected messages while a database resumes.

**De-duplication.** Each line is reduced to a fingerprint (timestamps, UUIDs, hex ids and numbers
replaced). A fingerprint that was mailed for the same log group within `dedup_window_in_minutes`
does not cause another e-mail; the suppressed occurrences are counted and reported in the next
e-mail for that message after the window. The state is a DynamoDB table
(`<kebab_case_name_prefix>log-notifier-dedup`, on-demand, TTL, point-in-time recovery), whose cost
is near zero. `dedup_window_in_minutes = 0` turns this off and creates no table. If DynamoDB is not
reachable, the Lambda sends the e-mail anyway.

**E-mail.** One e-mail per batch of lines delivered by CloudWatch Logs (usually a few seconds of
logs of one log stream):

- subject `[<email_subject_prefix>] <n> error lines in <last part of the log group name>`;
- log group, log stream, number of lines and distinct messages, first and last timestamp, the
  number of identical lines suppressed since the previous e-mail, and a console link to the stream;
- up to `max_sample_lines` lines (one per distinct message first), each shortened to 4,000
  characters; the message stays below the SNS size limit.

## Inputs

| Name | Default | Description |
|---|---|---|
| `application`, `customer`, `project` | | Tags. |
| `aws_region` | | Region of the resources. |
| `camel_case_name_prefix` | | Prefix of the IAM role and policy names. |
| `kebab_case_name_prefix` | | Prefix of the Lambda, SNS topic, DynamoDB table and filter names. |
| `email_subject_prefix` | | Shown in brackets at the start of the subject. |
| `log_group_arn`, `log_group_name` | | The log group to watch. |
| `log_receiver_email_address` | | E-mail subscription of the SNS topic (needs confirmation). |
| `log_retention_in_days` | | Retention of the notifier's own log group. |
| `filter_pattern` | `null` | Subscription filter pattern; `null` uses the built-in pattern above. |
| `exclude_patterns` | `[]` | Regular expressions of lines to drop. |
| `dedup_window_in_minutes` | `60` | Window for identical messages; `0` turns de-duplication off. |
| `dedup_table_deletion_protection` | `false` | Deletion protection of the DynamoDB table. |
| `max_sample_lines` | `20` | Lines quoted per e-mail. |
| `lambda_runtime` | `python3.13` | Runtime of the notifier Lambda. |
| `log_notifier_lambda_name_src_file_path` | `../python/lambda_function.py` | Lambda source, relative to `modules/terraform`. |
| `log_notifier_lambda_target_path` | `../target/lambda_function.zip` | Where the zip is written; use one path per module instance. |

## Outputs

| Name | Description |
|---|---|
| `filter_pattern` | Pattern in use. |
| `default_filter_pattern` | Built-in pattern. |
| `sns_topic_arn` | SNS topic of the notifications. |

## License

Apache 2.0, see `LICENSE`.
