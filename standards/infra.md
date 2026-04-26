# Infrastructure / CI / Secrets

## Rule: Never update AWS Secrets Manager via CLI

**Do:** Update secret values through GitHub Secrets and the `Update AWS Secret in Secrets Manager` workflow (`aws-update-secret-value.yml`).
**Don't:** Run `aws secretsmanager put-secret-value` / `update-secret` from a developer machine or ad-hoc script.
**Why:** Centralized auditable rotation; prevents drift and unlogged changes.
**Detection:** `aws secretsmanager (put-secret-value|update-secret)` in any script, doc, or PR diff.

## Rule: Don't report service failures through the same service channel

**Do:** Log service failures to structured logging (files, log aggregators). Set up external alerting (e.g. Splunk, CloudWatch) to monitor those logs and notify on-call engineers.
**Don't:** Configure a service to report its own failures by using the same channel (e.g. email error handler that sends email, SMS alert that sends SMS, push notification for push service failures).
**Why:** If the service fails, the error-reporting mechanism will also fail, creating a blind spot. External monitoring is reliable because it's out-of-band — it doesn't depend on the service being monitored.
**Source:** https://github.com/cobank-acb/ama-auditboard-workflow/pull/67#discussion_r3080012302
**Detection:** A service configuration with an error handler or fallback that uses the same channel as the service (e.g. `onErrorNotify` or `onFailureSendAlert` using email when the service sends email).
