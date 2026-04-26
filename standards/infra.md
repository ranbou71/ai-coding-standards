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

## Rule: Match tfvars literal types to the variable's declared type

**Do:** Write tfvars values using the literal type that matches the variable's declared `type` — unquoted numbers for `number`, unquoted booleans for `bool`, quoted strings only for `string`. Example: `RETRY_LIMIT = 2` (not `"2"`) when `variable "RETRY_LIMIT" { type = number }`.
**Don't:** Quote numeric or boolean values in tfvars (e.g. `RETRY_LIMIT = "2"`, `ENABLED = "true"`) and rely on Terraform's implicit string-to-number/bool coercion.
**Why:** Terraform usually coerces, but the implicit conversion hides type mismatches and makes diffs ambiguous (`"2"` vs `2` look the same to a human but mean different things to the type system). Matching the literal type keeps tfvars unambiguous, makes type errors fail loudly at plan time, and keeps grep/diff reviews honest.
**Source:** https://github.com/cobank-acb/ama-people-event-publisher/pull/16#discussion_r3101242745
**Detection:** A tfvars assignment where the right-hand side is a quoted string but the corresponding `variable` block declares `type = number` or `type = bool`.

## Rule: Dockerfile — copy `package*.json` and run `npm ci` before copying source

**Do:** Order Dockerfile layers so dependency installation is its own cacheable step. Copy `package.json` and `package-lock.json` first, run `npm ci`, then copy source trees (`src/`, `cronjobs/`, etc.). This way the slow `npm ci` layer is only invalidated when dependencies actually change.
**Don't:** Copy source directories (`COPY src ./src`, `COPY cronjobs ./cronjobs`) before copying `package*.json` and running `npm ci`. Every source change will bust the install layer and re-download the entire dependency tree, slowing local builds and CI.
**Why:** Docker layer caching is keyed on the inputs to each `COPY`/`RUN`. Copying source before installing dependencies means the install layer is invalidated on every code change — turning a 5-second incremental build into a multi-minute full rebuild and burning CI minutes.
**Example:**

```dockerfile
WORKDIR /usr/src/app
COPY package.json package-lock.json ./
RUN npm ci
COPY src ./src
COPY cronjobs ./cronjobs
# ...
```

**Source:** https://github.com/cobank-acb/ama-people-event-publisher/pull/21#discussion_r3118712204
**Detection:** A `COPY src` (or any source directory) that appears in the Dockerfile _before_ `COPY package*.json ./` and `RUN npm ci`/`yarn install`/`pnpm install`.

## Rule: Code must validate required configuration at startup

**Do:** At service startup, validate all required configuration variables are set. If a variable is required by code, either:

- Define a sensible default in `variables.tf` AND code must not assume it exists without checking, OR
- Document which environments must override it in their `.tfvars` file, OR
- Validate and fail fast with a clear error message if required config is missing.

**Don't:** Remove environment-specific `.tfvars` overrides without verifying code gracefully handles the base default. Don't silently use undefined/null values.

**Why:** Prevents runtime failures after deployment (like cron jobs failing immediately). Makes configuration requirements explicit and discoverable.

**Detection:** Service startup errors due to missing environment variables; `.tfvars` removals without corresponding code changes or validation.

## Rule: Config accessors must not silently default required values to empty strings

**Do:** For required configuration (SNS topic ARN, DynamoDB table name, etc.), throw an error if the env var is missing:

```typescript
static get SNS_TOPIC_ARN(): string {
  const value = process.env.SNS_TOPIC_ARN;
  if (!value) {
    throw new Error('Missing required environment variable: SNS_TOPIC_ARN');
  }
  return value;
}
```

**Don't:** Silently default to empty string:

```typescript
// BAD: leads to hard-to-debug AWS errors later
static get SNS_TOPIC_ARN(): string {
  return process.env.SNS_TOPIC_ARN || '';
}
```

**Why:** Empty strings pass validation but fail at runtime when used (e.g., trying to publish to SNS topic "", scanning DynamoDB table ""). Failing fast during config load makes errors immediately obvious and debuggable.

**Detection:** Config getter methods returning `|| ''` or `?? ''` for required values; AWS SDK errors about empty/invalid resource names.
