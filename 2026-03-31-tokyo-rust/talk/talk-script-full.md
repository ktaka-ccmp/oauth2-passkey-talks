# Talk Script: Full Version (slides-v2-full.md)

Estimated time: ~20–25 min (including 3–5 min live demo)

---

## Slide 1: Title — oauth2-passkey

"Hi everyone. I'm going to talk about a passwordless authentication library I built for Rust — called oauth2-passkey. It combines Passkey and OAuth2, and integrates with Axum."

---

## Slide 2: Live Demo (section lead)

"Let me start with a demo."

---

## Slide 3: Demo

"Watch the screen. I'll log in with Google first. After login, the library automatically prompts me to register a Passkey — fingerprint or face ID. Once registered, next time I can log in with just biometrics — no redirect to Google. And both methods are linked to the same account. (run demo) The diagram on the right shows what happened internally: one user, multiple OAuth2 accounts, multiple Passkey credentials — all linked. If you want to try it yourself, scan this QR code."

---

## Slide 4: Motivation

"Why did I build this? When I wanted to write a web app in Rust, there was no library that supported both OAuth2 and Passkey and integrated with Axum. OAuth2 lets you delegate authentication to a trusted provider — no passwords to manage. Passkey is phishing-resistant and has no server-side secrets. I wanted both, so I built it and published it to crates.io."

---

## Slide 5: Agenda

"Here's the plan for today: how OAuth2 and Passkey work, how to use the library, the internals of multi-DB support, how to integrate with your own app, and a wrap-up."

---

## Slide 6: How OAuth2/OIDC Works

"OAuth2 is a page-redirect flow. The user gets redirected to Google, authenticates there, and Google sends back a code. The server exchanges that code for an ID token, extracts the user identity, and creates a session. The user's password never touches your server."

---

## Slide 7: How Passkey/WebAuthn Works

"Passkey is JavaScript-driven — no page redirect. The server generates a random challenge, the browser passes it to the WebAuthn API, and the Authenticator signs it with the user's private key. The server verifies with the public key and creates a session. Authenticators include Google Password Manager, Apple, Windows Hello, and YubiKey."

---

## Slide 8: Using the Library (section lead)

"Now let's look at how to actually use the library."

---

## Slide 9: .env Setup (Minimal)

"The minimal config is just these env vars: your origin, Google client ID and secret, and the data store settings. For development, SQLite and in-memory cache — no DB setup required. To switch to PostgreSQL in production, just change the env vars and restart. No code changes. Data store supports SQLite, PostgreSQL, and MySQL. Cache supports in-memory and Redis."

---

## Slide 10: How to Use

"Using the library is three steps. Import AuthUser and oauth2_passkey_full_router. Call init() — this sets up the internal DB and state. Merge oauth2_passkey_full_router() into your router. That's it. Under /o2p/*, you now have OAuth2 endpoints, Passkey endpoints, login UI, account management, and admin panel — all included."

---

## Slide 11: Page Protection: AuthUser Extractor

"To protect a route, just add AuthUser as a handler argument. If authenticated, you get the user. If not, the library automatically redirects to login or returns 401. Use Option<AuthUser> for optional auth — unauthenticated requests get None instead of a redirect. Under the hood, this is Axum's FromRequestParts trait. AuthUser's rejection type is AuthRedirect: GET requests redirect to login, everything else returns 401. Option<AuthUser> implements OptionalFromRequestParts, which maps errors to None — so no redirect happens. The limitation: it always hits the DB, and GET always redirects. If you need more control, use Middleware."

---

## Slide 12: Page Protection: Middleware

"Middleware gives you finer control — skip the DB query, or return 401 even on GET. Just pass a function to route_layer with from_fn. In your handler, access CsrfToken or AuthUser via Extension."

---

## Slide 13: Page Protection: Middleware Variants

"There are four middleware variants. The _redirect vs _401 suffix controls the response for unauthenticated requests. The _user suffix means the middleware queries the DB and injects AuthUser into the handler. Without _user, no DB query — you just get CsrfToken. Pick the one that fits your use case."

---

## Slide 14: Storage & LazyLock Pattern (section lead)

"Now let's look at how multi-DB support works internally."

---

## Slide 15: Switch DB by Changing .env

"Switching DBs is just env vars. SQLite, PostgreSQL, MySQL/MariaDB, in-memory or Redis cache. No code changes."

---

## Slide 16: How Multi-DB Support Works Internally

"Three steps to understand this. First, a LazyLock static reads the GENERIC_DATA_STORE_TYPE env var at startup and creates the appropriate DataStore — SqliteDataStore, PostgresDataStore, or MySqlDataStore — wrapped in a Box<dyn DataStore>. Second, the DataStore trait has three methods: as_sqlite, as_postgres, as_mysql. Each concrete type returns Some for its own pool and None for the others. Third, callers match on the tuple of all three. If GENERIC_DATA_STORE_TYPE=sqlite, the match arm (Some(pool), _, _) fires and get_all_users_sqlite runs. Change the env var to postgres, and a different match arm fires — same calling code, different backend."

---

## Slide 17: Why LazyLock Instead of Axum State?

"If the library used Axum State, users would need to embed the library's AuthState into their own AppState struct. With LazyLock globals, users just call init(). The library holds everything internally. For users: no need to know about library internals. For library development: any internal function can access the DB directly, without threading State through 80+ functions. It's a deliberate trade-off."

---

## Slide 18: Integrating with Your App (section lead)

"Now let's look at integration patterns."

---

## Slide 19: Integrating Your App: 1:N Schema (demo-todo)

"First, a 1:N example — a todo app. The schema is simple: a todos table with a user_id column that references oauth2-passkey's users.id. An index on user_id is essential for per-user queries. Your app DB and the library's DB can be the same or separate."

---

## Slide 20: Integrating Your App: 1:N Handler (demo-todo)

"Here's the handler. We extract the routes into a todos_router() function and apply is_authenticated_redirect with route_layer. In the create_todo handler, we take State, AuthUser, and Form, and save user.id as todos.user_id. Three key points: your AppState holds your own DB pool independent of the library; the middleware protects routes without a DB query at the route level; and you pass user.id as the FK."

---

## Slide 21: Integrating Your App: 1:1 Schema (demo-profile)

"For a 1:1 relationship — a user profile — the key is user_id TEXT PRIMARY KEY. Making it both the PK and FK enforces the 1:1 constraint at the DB level. No separate id column needed. The profile is auto-created on first login."

---

## Slide 22: Integrating Your App: 1:1 Handler (demo-profile)

"The structure is the same as the todo handler. profile_router() groups the protected routes. In update_profile, we call db::upsert_profile with user_id as the key. Upsert handles both create and update atomically — first visit creates, subsequent visits update."

---

## Slide 23: Wrap-up (section lead)

"To wrap up."

---

## Slide 24: Summary

"Three takeaways. Easy: init() and merge — that's all you need, UI included. Secure: Passkey is phishing-resistant, combined with OAuth2, plus CSRF protection and secure session cookies. Flexible: swap SQLite / PostgreSQL / MySQL / Redis by changing env vars only."

---

## Slide 25: Thank You / Questions?

"That's it. The GitHub repo is here. Feedback and questions are very welcome. Thank you."

---

## Extra Slides (for Q&A)

See `talk-script-extra.md` for scripts for each backup slide.
