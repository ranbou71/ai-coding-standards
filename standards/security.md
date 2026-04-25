# Security

## Rule: Validate at system boundaries only

**Do:** Validate untrusted input where it enters the system (HTTP handlers, queue consumers, CLI args).
**Don't:** Add defensive checks for conditions that cannot occur internally.
**Why:** Internal defensive code is dead weight and hides real bugs.

## Rule: Watch for OWASP Top 10

**Do:** Treat injection, broken auth, SSRF, insecure deserialization, etc. as blockers.
**Don't:** Concatenate untrusted input into SQL, shell, HTML, or URLs.
**Detection:** String interpolation into `exec`, `eval`, raw SQL, shell calls.
