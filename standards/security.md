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
**Detection:** `console.error(error)` or `logger.error(error)` or `console.log(process.env)` or `console.error(response)` in middleware/handlers.
**Example fix:** Replace `console.error('Error:', error)` with `console.error('An error occurred while fetching AuditBoard controls.')` — static message only, no error object.
