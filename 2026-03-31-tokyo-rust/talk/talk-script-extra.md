# Talk Script: Extra Slides (Q&A Backup)

These slides are available in both versions. Use them when questions arise.
Slides marked **(short only)** appear only in slides-v2-short.md's extra section.

---

## What the Demo Showed *(short only)*

"Let me go through what the demo covered in more detail. Google OAuth2 login — the library handles the full redirect flow and creates a user in the DB. After login, it automatically prompts Passkey registration — that's the Passkey Promotion feature. Passkey authenticators can be Google Password Manager, Apple, Windows Hello, bitwarden, Proton Pass, or a hardware key like YubiKey. Both methods get linked to the same user account. The login page, account management, and admin panel are all built into the library — you don't build them from scratch."

---

## Flow: Google Login → Passkey Setup *(short only)*

"Here's the full picture of how account linking works. When a user first logs in with Google, the library creates a user record in the DB. Then Passkey Promotion kicks in — the user registers a Passkey, and it gets linked to the same user. From then on, either method works. On the right, you can see the DB structure: one user can have multiple OAuth2 accounts — say, Google and GitHub — and multiple Passkey credentials — a laptop, a phone, a YubiKey. They all resolve to the same user ID."

---

## How OAuth2/OIDC Works *(short only)*

"For those unfamiliar with OAuth2: it's a page-redirect flow. The user clicks 'Login with Google', gets redirected to Google, authenticates there, and Google redirects back with an authorization code. The server exchanges that code for an ID token, extracts the user identity, and creates a session. The key point is that the user's password never touches your server — Google handles it."

---

## How Passkey/WebAuthn Works *(short only)*

"Passkey is different — it's JavaScript-driven, no page redirect. The server generates a random challenge, the browser passes it to the WebAuthn API, and the Authenticator signs it with the user's private key. The server verifies the signature with the previously-registered public key and creates a session. The private key never leaves the device. Authenticators include Google Password Manager, Apple Passwords, Windows Hello, and hardware keys like YubiKey."

---

## Page Protection: Middleware Variants *(short only)*

"Here's the full comparison table. There are four variants. The _redirect variants redirect to the login page on auth failure — suited for web pages. The _401 variants always return HTTP 401 — suited for APIs. The _user variants query the DB and inject AuthUser into the handler via Extension. Without _user, there's no DB query and only CsrfToken is available. So you have two independent axes: response type and whether to fetch the user."

---

## How Multi-DB Support Works Internally *(short only)*

"Three steps to understand this. First, a LazyLock static reads the GENERIC_DATA_STORE_TYPE env var at startup and creates the appropriate DataStore — SqliteDataStore, PostgresDataStore, or MySqlDataStore — wrapped in a Box<dyn DataStore>. Second, the DataStore trait has three methods: as_sqlite, as_postgres, as_mysql. Each concrete type returns Some for its own pool and None for the others. SqliteDataStore returns Some only from as_sqlite. Third, callers match on the tuple of all three. If GENERIC_DATA_STORE_TYPE=sqlite, the match arm (Some(pool), _, _) fires and get_all_users_sqlite runs. Change the env var to postgres, and a different match arm fires — same calling code, different backend."

---

## Why LazyLock Instead of Axum State? *(short only)*

"If the library used Axum State, users would need to embed the library's AuthState into their own AppState struct. Every time you add a new library with its own State, you have to update your AppState definition. With LazyLock globals, users just call init(). The library holds everything internally. There's no struct to compose, no state to pass around. The trade-off: the library's DB access is implicit — you can't see it from function signatures. And tests need serial execution because of shared global state. For an auth library used as infrastructure, this trade-off is worth it."

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

---

## Integrating Your App: 1:N Schema *(short only)*

"For a 1:N relationship like a todo app, add a user_id TEXT NOT NULL column to your table and create an index on it. user_id references oauth2-passkey's users.id — you get that value from AuthUser.id in your handler. The index is essential: most queries will be 'give me all todos for this user', and without the index that's a full table scan. Your app's DB and the library's DB can be the same SQLite file or separate databases — your choice."

---

## Integrating Your App: 1:N Handler *(short only)*

"Wrap your routes in a function — todos_router() here — and apply the middleware with route_layer. This is cleaner than applying middleware inline in main, and it makes the protected routes explicit. In the create_todo handler, you receive AppState, AuthUser, and the form data. You pass user.id as the foreign key when writing to your DB. Your AppState only holds your DB pool — you never touch the library's storage directly. The middleware already verified the session, so no extra DB query happens at the route level."

---

## Integrating Your App: 1:1 Schema *(short only)*

"For a 1:1 relationship like a user profile, make user_id the PRIMARY KEY. Since user_id is also a FK to users.id, making it the PK enforces the one-to-one constraint at the database level — you literally cannot have two profiles for the same user. No separate id column is needed. This is simpler than having a separate UNIQUE constraint. The profile doesn't exist until the user's first login, so the handler creates it on first write using upsert."

---

## Integrating Your App: 1:1 Handler *(short only)*

"Same structure as the todo handler — extract routes into profile_router(), apply middleware. The key difference in the handler is db::upsert_profile. Upsert is INSERT ... ON CONFLICT DO UPDATE — it creates the record if it doesn't exist, or updates it if it does. This is atomic: no race condition between a check-then-insert sequence. For a profile, this means the first POST creates the profile, subsequent POSTs update it — handled in one query without the handler needing to know which case it is."
