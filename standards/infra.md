# Infrastructure / CI / Secrets

## Rule: Never update AWS Secrets Manager via CLI

**Do:** Update secret values through GitHub Secrets and the `Update AWS Secret in Secrets Manager` workflow (`aws-update-secret-value.yml`).
**Don't:** Run `aws secretsmanager put-secret-value` / `update-secret` from a developer machine or ad-hoc script.
**Why:** Centralized auditable rotation; prevents drift and unlogged changes.
**Detection:** `aws secretsmanager (put-secret-value|update-secret)` in any script, doc, or PR diff.
