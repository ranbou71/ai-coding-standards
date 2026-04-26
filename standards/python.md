# Python

_(Add rules as PR comments produce them.)_


## Rule: Use `logger.exception(...)` inside `except`; don't f-string interpolate the exception

**Do:** Inside an `except` block, use `logger.exception("Static message describing what failed", extra={"key": value})`. This emits the log record at ERROR level _and_ attaches the full traceback automatically, without requiring you to convert the exception to a string. Pass diagnostic context through `extra=` (or via the `%s` lazy formatting style: `logger.error("Failed for index %s", index)`).
**Don't:** Write `logger.error(f"Failed: {e}")` or `logger.error(f"Failed: {str(e)}")`. The f-string forces `str(e)` immediately; some exception classes raise during their own `__str__`/`__repr__` (libraries that pull objects from streams, response-bound exceptions whose body has already been consumed, exceptions whose state was mutated by a finalizer). Your error-handling path then crashes _while handling the original error_, masking the real failure with a `TypeError: __str__ returned non-string` or similar.
**Why:** `logger.exception` is the idiomatic Python pattern for a reason — it captures the traceback via `sys.exc_info()` (no stringification of the exception object required), it emits at the correct level, and it survives exceptions whose `__str__` is unsafe. F-string interpolation in error paths is one of the most common ways "the error handler crashed" appears in production. The fix is mechanical: `logger.error(f"... {e}")` → `logger.exception("...")`.
**Example fix:** Replace `except Exception as e: logger.error(f"Unexpected error retrieving facets for index {index}: {e}")` with `except Exception: logger.exception("Unexpected error retrieving facets for index %s", index)`. If you need the exception type/message as structured fields, use `extra={"exception_type": type(e).__name__}` — never `str(e)` on an exception you didn't construct.
**Source:** https://github.com/cobank-acb/shd-unified-search-api/pull/150#discussion_r3001666520
**Source:** https://github.com/cobank-acb/shd-unified-search-api/pull/150#discussion_r3001666545
**Detection:** Any `except ... as e:` block containing `logger.<level>(f"... {e}...")` / `logger.<level>(f"... {str(e)}...")` / `logger.<level>("..." + str(e))`. Or: any `except` block that doesn't use `logger.exception(...)` and has no other mechanism for capturing the traceback.
