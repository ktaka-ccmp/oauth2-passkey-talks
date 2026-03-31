# Talk Script: Full Version (slides-v2.md)

Estimated time: ~20–25 min (including 3–5 min live demo)

---

## Slide 1: Title — oauth2-passkey

"Hi everyone. I'm going to talk about a passwordless authentication library I built for Rust — called oauth2-passkey. It combines Passkey and OAuth2, and integrates with Axum."

---

## Slide 2: Live Demo (section lead)

"Let me start with a demo."

---

## Slide 3: Demo (QR code)

"Watch the screen. I'll log in with Google first. After login, the library automatically prompts me to register a Passkey — fingerprint or face ID. Once registered, next time I can log in with just biometrics — no redirect to Google. And both methods are linked to the same account. (run demo) If you want to try it yourself, scan this QR code."

---

## Slide 4: What the Demo Showed

"To recap what you just saw: Google OAuth2 login, automatic Passkey promotion after login, Passkey login next time, and account linking. The login page and account management UI are all built into the library — you don't build them from scratch. All of this is handled by a single library: oauth2-passkey."

---

## Slide 5: Motivation

"Why did I build this? When I wanted to write a web app in Rust, there was no library that supported both OAuth2 and Passkey and integrated with Axum. OAuth2 lets you delegate authentication to a trusted provider — no passwords to manage. Passkey is phishing-resistant and has no server-side secrets. I wanted both, so I built it and published it to crates.io."

---

## Slide 6: Agenda

"Here's the plan for today: how OAuth2 and Passkey work, how to use the library, the internals of multi-DB support, how to integrate with your own app, and a wrap-up."

---

## Slide 7: Flow: Google Login → Passkey Setup

"Let me walk through the overall flow. First, OAuth2 login with Google — the library creates a user in the DB linked to that Google account. Then Passkey promotion — the user registers a Passkey, which gets linked to that same user. Next time, they can log in with either Passkey or Google. On the right you can see the result: one user can have multiple OAuth2 accounts and multiple Passkey credentials attached."

---

## Slide 8: How OAuth2/OIDC Works

"OAuth2 is a page-redirect flow. The browser gets redirected to Google, the user authenticates, Google sends back a code, the server exchanges it for an ID token, and the server creates a session. That's the whole flow."

---

## Slide 9: How Passkey/WebAuthn Works

"Passkey is JavaScript-driven. The server generates a challenge, passes it to the browser WebAuthn API, the Authenticator signs it with the private key, and the server verifies with the public key and creates a session. The Authenticator can be Google Password Manager, Apple, Windows Hello, YubiKey, and others."

---

## Slide 10: Using the Library (section lead)

"Now let's look at how to actually use the library."

---

## Slide 11: .env Setup (Minimal)

"The minimal config is just these env vars: your origin, Google client ID and secret, and the data store settings. For development, SQLite and in-memory cache — no DB setup required. If you want to switch to PostgreSQL in production, just change the env vars and restart. No code changes. Data store supports SQLite, PostgreSQL, and MySQL. Cache supports in-memory and Redis."

---

## Slide 12: How to Use

"Using the library is three steps. First, import AuthUser and oauth2_passkey_full_router. Second, call init() — this sets up the internal DB and state. Third, merge oauth2_passkey_full_router() into your router. That's it. Under /o2p/*, you now have OAuth2 endpoints, Passkey endpoints, login UI, account management, and admin panel — all included."

---

## Slide 13: Page Protection: AuthUser Extractor

"To protect a route, just add AuthUser as a handler argument. If authenticated, you get the user. If not, the library automatically redirects to login or returns 401. Use Option<AuthUser> for optional auth — unauthenticated requests get None instead of a redirect. Under the hood, this is Axum's FromRequestParts trait. AuthUser's rejection type is AuthRedirect: GET requests redirect to login, everything else returns 401. Option<AuthUser> implements OptionalFromRequestParts, which maps errors to None — so no redirect happens. The limitation: it always hits the DB, and GET always redirects. If you need more control, use Middleware."

---

## Slide 14: Page Protection: Middleware

"Middleware gives you finer control — skip the DB query, or return 401 even on GET. Just pass a function to route_layer with from_fn. In your handler, access CsrfToken or AuthUser via Extension."

---

## Slide 15: Page Protection: Middleware Variants

"There are four middleware variants. The _redirect vs _401 suffix controls the response for unauthenticated requests. The _user suffix means the middleware queries the DB and injects AuthUser into the handler. Without _user, no DB query — you just get CsrfToken. Pick the one that fits your use case."

---

## Slide 16: Storage & LazyLock Pattern (section lead)

"Now let's look at how multi-DB support works internally."

---

## Slide 17: Switch DB by Changing .env

"As I mentioned, switching DBs is just env vars. SQLite, PostgreSQL, MySQL/MariaDB, in-memory or Redis cache. No code changes."

---

## Slide 18: How Multi-DB Support Works Internally

"There are three steps. First, a LazyLock reads the env var at startup and creates a SqliteDataStore, PostgresDataStore, or MySqlDataStore wrapped in a Box. Second, the DataStore trait has as_sqlite, as_postgres, and as_mysql methods. SqliteDataStore returns Some for as_sqlite and None for the others. Third, callers match on the tuple and dispatch to the right function. So if GENERIC_DATA_STORE_TYPE=sqlite, the LazyLock holds a SqliteDataStore, as_sqlite returns Some, and get_all_users_sqlite runs."

---

## Slide 19: Why LazyLock Instead of Axum State?

"If the library used Axum State, users would have to embed the library's state into their AppState. That's friction. With LazyLock globals, users just call init(). The library holds its state internally — no state threading required. For users: no need to know about library internals. For library development: any internal function can access the DB directly, without threading State through 80+ functions. It's a deliberate trade-off."

---

## Slide 20: Integrating with Your App (section lead)

"Now let's look at integration patterns."

---

## Slide 21: Integrating Your App: 1:N Schema (demo-todo)

"First, a 1:N example — a todo app. The schema is simple: a todos table with a user_id column that references oauth2-passkey's users.id. An index on user_id is essential for per-user queries. Your app DB and the library's DB can be the same or separate."

---

## Slide 22: Integrating Your App: 1:N Handler (demo-todo)

"Here's the handler. We extract the routes into a todos_router() function and apply is_authenticated_redirect with route_layer. In the create_todo handler, we take State, AuthUser, and Form, and save user.id as todos.user_id. Three key points: your AppState holds your own DB pool independent of the library; the middleware protects routes without a DB query at the route level; and you pass user.id as the FK."

---

## Slide 23: Integrating Your App: 1:1 Schema (demo-profile)

"For a 1:1 relationship — a user profile — the key is user_id TEXT PRIMARY KEY. Making it both the PK and FK enforces the 1:1 constraint at the DB level. No separate id column needed. The profile is auto-created on first login."

---

## Slide 24: Integrating Your App: 1:1 Handler (demo-profile)

"The structure is the same as the todo handler. profile_router() groups the protected routes. In update_profile, we call db::upsert_profile with user_id as the key. Upsert handles both create and update atomically — first visit creates, subsequent visits update."

---

## Slide 25: Wrap-up (section lead)

"To wrap up."

---

## Slide 26: Summary

"Three takeaways. Easy: init() and merge — that's all you need, UI included. Secure: Passkey is phishing-resistant, combined with OAuth2, plus CSRF protection and secure session cookies. Flexible: swap SQLite / PostgreSQL / MySQL / Redis by changing env vars only."

---

## Slide 27: Thank You / Questions?

"That's it. The GitHub repo is here. Feedback and questions are very welcome. Thank you."

---

## Extra Slides (for Q&A)

The backup slides cover:

- **Why Not Axum State: State Threading Problem** — cost of threading state through 80+ internal functions
- **AuthUser: FromRequestParts Implementation** — actual code, AuthRedirect implementation
- **What is LazyLock? / Benefits & Trade-offs** — LazyLock basics and trade-offs
- **Middleware: Why Not Just Use the Extractor?** — two axes of control
- **Newtype Wrappers** — type safety, validation in constructors
- **Error Hierarchy / From Impls with Auto-Logging** — error hierarchy and automatic logging
- **Security: Constant-Time Comparison** — timing attack prevention in CSRF validation
- **Atomic SQL / SQL Dialect Differences** — transaction-free SQL, dialect handling
- **Integrating: 1:N / 1:1 Schema & Handler** — detailed integration code
