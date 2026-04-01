# Talk Script: Extra Slides (Q&A Backup)

These slides are in the Extra Slides section of slides-v2-full.md. Use them when questions arise during Q&A.

---

## Why Not Axum State: The State Threading Problem

"Here's a concrete example of why State threading is painful at scale. If only the grandchild function needs DB access, you still have to thread State through parent and child — they don't use it at all, but they must accept it and pass it down. The library has over 80 internal functions. If it used State, all 80+ would need a &State parameter, even the ones that just call something else. With LazyLock, parent and child have no idea the DB exists. Only grandchild touches it. The code is simpler and the call sites are cleaner."

---

## AuthUser: FromRequestParts Implementation

"Here's the actual implementation. from_request_parts first grabs the session cookie from the request. If there's no cookie, it returns AuthRedirect immediately. Then it validates the session by querying the DB — get_user_and_csrf_token_from_session. If that fails, again AuthRedirect. On success it returns the AuthUser. AuthRedirect is the rejection type — it implements IntoResponse. If the original request method was GET, it issues a temporary redirect to the login URL. Any other method gets a 401 Unauthorized. That's why GET requests to a protected page redirect to login, while POST requests from an API client get a 401. For Option<AuthUser>, we implement OptionalFromRequestParts explicitly. It calls the AuthUser extractor and maps any Err to Ok(None). So the request always succeeds — no redirect, no 401 — you just get None in the handler."

---

## What is LazyLock?

"LazyLock is in the Rust standard library since 1.80. It's a static value that's initialized once, on first access, and then shared immutably across threads. In this example, CONFIG is evaluated the first time anyone calls *CONFIG. After that, the closure never runs again. It's thread-safe by design. You may know lazy_static! — LazyLock is the same idea but in std, without the macro or extra crate."

---

## LazyLock: Benefits & Trade-offs

"Let me be explicit about the trade-offs. Benefits: users get zero boilerplate — no AppState to compose. No state threading — any function can hit the DB directly. Switching DBs is just changing env vars. And init() fails fast at startup if anything is misconfigured — you find out immediately, not at runtime. Trade-offs: it's a single instance per process, which is fine for an auth library. Dependencies are implicit — the function signature doesn't tell you it accesses the DB. And tests share global state, so parallel test execution breaks — you need #[serial] from the serial_test crate. I made this trade-off deliberately: Rust purists would use State, but LazyLock keeps all the complexity inside the library, invisible to users."

---

## Middleware: Why Not Just Use the Extractor?

"The AuthUser extractor is convenient but opinionated: it always redirects on failure, and it always queries the DB. That works great for web pages, but an API endpoint should return 401 JSON — not a redirect to an HTML login page. And sometimes you just need to verify 'is this session valid?' without loading the full user record. Middleware solves this with two independent axes. Response type: _redirect variants redirect to the login page, _401 variants always return 401 — choose based on whether you're serving HTML or JSON. Extension injected: _user variants query the DB and make AuthUser available via Extension; non-_user variants skip the DB entirely and only inject CsrfToken. So is_authenticated_401 is: no DB, always 401 — good for stateless API auth checks. is_authenticated_user_redirect is: DB query, redirect on failure — good for web pages that need the user object."

---

## Newtype Wrappers: Type Safety

"The library uses newtype wrappers extensively. CsrfToken, UserId, SessionId, SessionCookie — they're all just Strings internally, but the types are distinct. Without newtypes, check(session_id, user_id) and check(user_id, session_id) both compile — the second one is a bug that the compiler won't catch. With newtypes, the second call is a compile error. Same thing for bools: CsrfHeaderVerified and AuthenticationStatus are separate types so you can't mix them up. The compiler enforces correctness."

---

## Newtype Wrappers: Validation in Constructors

"The other benefit of newtypes is centralizing validation. UserId::new checks that the string is non-empty, under 255 characters, and contains only allowed characters. If construction succeeds, you have a guaranteed-valid UserId. Everywhere else in the codebase that accepts a UserId, you don't need to re-validate — the type contract already guarantees it. Parse, don't validate."

---

## Error Hierarchy with thiserror

"Each module — OAuth2, Passkey, Session, User — has its own error type. The coordination layer has CoordinationError, which wraps all of them via enum variants. thiserror generates the Display and Error implementations from the #[error(...)] attributes. ResourceNotFound even carries structured data — resource_type and resource_id — in the error message, which shows up in logs automatically. When an inner error propagates up with ?, it gets wrapped in the appropriate variant."

---

## From Impls with Auto-Logging

"Here's a pattern I'm particularly happy with. Each From impl — converting OAuth2Error into CoordinationError, for example — calls tracing::error! before returning. So every time the ? operator crosses a module boundary, the error is automatically logged at the error level. In practice, any time something goes wrong in the OAuth2 flow, you get a log line without any manual tracing::error! calls in the business logic. The error propagates up cleanly, and the log is there for free."

---

## Security: Constant-Time Comparison

"This one is subtle. When you compare two strings with ==, Rust short-circuits on the first byte mismatch — it returns false immediately. An attacker can measure response time across many requests and gradually guess the correct token byte by byte, because correct prefixes take slightly longer. ct_eq from the subtle crate always compares every byte regardless of where the mismatch is — the execution time is constant. We use this for CSRF token verification, session validation, and any other security-sensitive string comparison."

---

## CSRF Protection: Batteries Included

"CSRF protection is fully integrated — you don't need to add a separate crate or wire anything up. When a session is created, a 32-byte random CSRF token is generated and stored alongside it in the cache. Every authenticated response automatically includes an X-CSRF-Token header — so the client always has the current token. There's also a dedicated endpoint at /o2p/user/csrf_token if you need it explicitly. The verification uses constant-time comparison, so timing attacks on the token are not possible. This all happens inside the library — zero setup for the user."

---

## CSRF: Verification Logic

"Here's how verification works, case by case. GET and other safe methods skip CSRF entirely — no token needed. For state-changing methods like POST, if the X-CSRF-Token header is present, the library verifies it with ct_eq. A mismatch is immediately rejected. If the header is absent but the Content-Type is a form type — application/x-www-form-urlencoded or multipart/form-data — the request is allowed through, and the handler is expected to verify the token from the form body. If the header is absent and it's not a form request, the library rejects it immediately. This logic is the same in both the AuthUser extractor and the is_authenticated_* middleware variants."

---

## CSRF: Usage Patterns

"There are two patterns depending on how you submit data. For AJAX requests, fetch the token from the X-CSRF-Token response header and include it in subsequent requests as a header. The library verifies it automatically — no handler code needed. For HTML forms, embed the token in a hidden field and do a manual constant-time comparison in the handler. The key check is csrf_via_header_verified — if the header was already verified upstream, you can skip the form check. Both patterns are documented with working examples in the demo-both application."

---

## Atomic SQL: No Explicit Transactions

"This query deletes a user, but only if they're not the last admin — that check is embedded in the WHERE clause as a subquery. The entire operation is a single SQL statement, which means it's atomic by default. No explicit BEGIN/COMMIT transaction, no risk of a race condition where two concurrent requests both see 'there's one admin left' and both try to delete. Business logic expressed in SQL is atomic at the statement level. We use this pattern throughout the library wherever the logic can be expressed in one query."

---

## SQL Dialect Differences

"Supporting three databases means handling their quirks. PostgreSQL supports RETURNING * in an upsert, so you can get the resulting row back in a single query. SQLite doesn't support RETURNING in all versions, so we have to do an insert then a separate select. MySQL has its own syntax differences too. Each backend has its own implementation functions — get_all_users_sqlite, get_all_users_postgres, get_all_users_mysql — and the dispatch happens via the DataStore trait as shown in the internals slide."

---

## LazyLock Initialization Flow

"This diagram shows the full initialization sequence. When init() is called, it evaluates all LazyLock statics immediately — data store, cache store, OAuth2 config, session config. If any env var is missing or invalid, init() fails right there at startup. You don't get a runtime error when the first user logs in. After init() returns successfully, any handler anywhere in the app can access GENERIC_DATA_STORE directly without any state parameter."

---

## Crate Structure (Detail)

"The library is split into two crates. oauth2_passkey is the core — it handles OAuth2, Passkey/WebAuthn, session management, user storage, and the DataStore abstraction. oauth2_passkey_axum is the Axum integration layer — it exposes the router, middleware functions, and the AuthUser extractor. The split means the core logic could theoretically be adapted to other frameworks in the future."

---

## From/Into: Clean Layer Boundaries

"The library has three internal layers: DB layer, session layer, and Axum layer. Each has its own user type — DbUser, SessionUser, AuthUser. From impls define the conversions. DbUser becomes SessionUser when loaded from the DB. SessionUser becomes AuthUser when handed to a handler. The Axum-specific fields — csrf_token, session_id — are added at the Axum layer and don't exist in the lower layers. This keeps each layer's type focused on its own concerns, and .into() calls do the conversion transparently."

---

## Future Plans

"A few things on the roadmap. DPoP — Demonstration of Proof-of-Possession — binds tokens to a cryptographic key, preventing stolen tokens from being replayed. Bearer Token support for API authentication beyond session cookies. FedCM — Federated Credential Management — is a browser-native identity API that avoids the page redirect entirely; there's a partial implementation already. And more OAuth2 providers — GitHub, Apple, Microsoft are the obvious next ones."
