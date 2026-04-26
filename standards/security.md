# Security

## Rule: Validate at system boundaries only

**Do:** Validate untrusted input where it enters the system (HTTP handlers, queue consumers, CLI args).
**Don't:** Add defensive checks for conditions that cannot occur internally.
**Why:** Internal defensive code is dead weight and hides real bugs.

## Rule: Watch for OWASP Top 10

**Do:** Treat injection, broken auth, SSRF, insecure deserialization, etc. as blockers.
**Don't:** Concatenate untrusted input into SQL, shell, HTML, or URLs.
**Detection:** String interpolation into `exec`, `eval`, raw SQL, shell calls.

## Rule: Don't log sensitive data; sanitize error messages

**Do:** Log only static, generic messages or carefully sanitized values. If logging an error, extract only safe fields (e.g., `error.message` or a status code).
**Don't:** Log full error objects, environment variables, API responses, request bodies, tokens, or any data that might contain secrets.
**Why:** Error objects can serialize and expose sensitive information embedded in stack traces, response bodies, or custom properties. Logs are often forwarded to external systems or accessed by multiple teams; once logged, secrets are impossible to fully revoke.
**Detection:** Any of: `console.error(error)`, `logger.error(error)`, `console.log(process.env)`, `console.error(response)`, `console.log('...', response)`, `logger.error('...', fullObject)`, or logging variables with names suggesting secrets: `console.log(...bearer_token...)`, `console.log(...password...)`, etc. Look for logging of entire objects/responses/requests, especially in error paths — log only status codes, error.message, or static descriptions instead.
**Example fix (full response):** Replace `console.log('Response:', response)` with `console.error('AuditBoard /controls request failed. Status: ${response.status}, Body: ${errorBody}')` where errorBody is a sanitized text extraction.
**Example fix (token):** Replace `console.log('Bearer Token:', bearer_token)` with `console.log('Using bearer token for AuditBoard /controls request')` — static message, no token value.
**Source:** https://github.com/cobank-acb/ama-auditboard-workflow/pull/31#discussion_r3029453951 and https://github.com/cobank-acb/ama-auditboard-workflow/pull/31#discussion_r3029453933

## Rule: Don't string-interpolate structured logging objects; pass them as separate arguments

**Do:** Pass structured data (objects, error objects, or the result of a logging helper) as a separate argument to the logger: `logger.error('Message', structuredData)` or `logger.error('Message', convertErrorForLogging(error))`.
**Don't:** Template-interpolate objects into the message: `logger.error(\`Message: ${errorHelper(error)}\`)` or `logger.error(\`Error: ${error}\`)`.
**Why:** String interpolation serializes objects to `[object Object]`, losing all the structured data. Most logging systems (Winston, Pino, Bunyan, etc.) accept multiple arguments and preserve structure in the second+ arguments for proper JSON serialization and querying.
**Detection:** `logger.error(\`...\${...}\`)` or `logger.error('...' + errorHelper(...))` when a helper function returns an object or when logging error data.
**Example fix:** Replace `logger.error(\`${convertErrorForLogging(error)}\`)`with`logger.error('[RuntimeMonitor] TTL exceeded; terminating process.', convertErrorForLogging(error));`
**Source:** https://github.com/cobank-acb/ama-auditboard-workflow/pull/31#discussion_r3029453879
