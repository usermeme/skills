# Security Review Checklist

Walk this list for any diff touching input handling, authentication/authorization, database queries, secrets, file access, or outbound network calls. For each item: construct the attack input, don't just eyeball the code — a security finding needs its failure scenario like any other ([SKILL.md](../SKILL.md) §1).

## Injection

- **SQL**: every query parameterized (`$1`/placeholders)? Any string interpolation into query *text* — including ORDER BY columns, table names, LIMIT — is a finding even if "the value comes from config today".
- **Command**: user-influenced values reaching `exec`/`spawn` with `shell: true`, or concatenated into shell strings. Prefer `execFile` with an args array.
- **Path traversal**: user input joined into file paths without normalization + prefix check (`../../etc/passwd`). Check upload filenames, download endpoints, template names.
- **Template/eval**: user content reaching `eval`, `Function`, template engines with code execution, or dynamic `require`/`import`.

## Authentication & authorization

- Every new endpoint/handler: who can call it? Missing auth middleware on admin/backfill/debug routes is a classic.
- **IDOR**: object fetched by user-supplied ID — is ownership/tenancy checked, or does any authenticated user reach any ID?
- Authorization at the *action*, not just the route: reading may be allowed where mutating isn't.
- Tokens/sessions: expiry enforced, verified with a constant-time comparison, signature actually checked (not just decoded).
- Webhooks: signature verified over the **raw** bytes before parsing, with a constant-time compare; reject on absence, not just mismatch.

## Secrets & sensitive data

- No credentials, API keys, or private keys in code, config committed to git, or defaults. Env/secret manager only.
- **Logs**: are tokens, passwords, PII, full request bodies being logged — including in error paths and exception messages? Clone URLs with embedded tokens are an easy leak.
- Error responses: stack traces, internal paths, or query text returned to clients.
- PII: new fields collected — is storage, retention, and exposure justified? (GDPR lens: could this row be deleted/exported per user?)

## Requests & resources

- **SSRF**: user-influenced URLs fetched server-side — can they reach internal hosts/metadata endpoints? Allowlist schemes and hosts.
- **Unbounded work**: request sizes limited, pagination capped, regex on user input safe from catastrophic backtracking, zip/archive extraction bounded (zip bombs), recursion depth-limited.
- **Redirects**: user-supplied redirect targets validated against an allowlist.
- Rate limiting / idempotency on endpoints that trigger expensive or paid work (LLM calls, emails, jobs).

## Web-specific (when reviewing frontend/SSR)

- **XSS**: user content rendered with `dangerouslySetInnerHTML`/`v-html`/manual DOM insertion; URLs in `href` allowing `javascript:`.
- **CSRF**: state-changing endpoints authenticated purely by cookies without CSRF token/SameSite defense.
- Uploaded content served from the app origin with sniffable content types.

## Concurrency & state

- **TOCTOU**: check-then-act across async boundaries (balance check → debit; lock check → write) without a transaction or atomic operation.
- Locks/idempotency keys: released on error paths? Scoped tightly enough to prevent double-execution, broadly enough to matter?

## Crypto & dependencies

- No hand-rolled crypto, no MD5/SHA1 for security purposes, no `Math.random()` for tokens — `crypto.randomUUID`/`randomBytes`.
- New dependencies: maintained, pinned, no known critical CVEs? A transitive dependency added for ten lines of code is attack surface, not convenience.
