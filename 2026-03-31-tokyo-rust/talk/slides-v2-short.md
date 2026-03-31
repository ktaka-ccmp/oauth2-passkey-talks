---
marp: true
theme: default
paginate: true
size: 16:9
style: |
  section {
    font-size: 24px;
    display: flex !important;
    flex-flow: column nowrap !important;
    justify-content: flex-start !important;
    padding: 40px 60px 25px 60px !important;
  }
  section:not(.lead) > h2:first-of-type {
    margin-top: 0 !important;
    margin-bottom: 0.15em;
  }
  section.lead {
    justify-content: center !important;
    align-items: center !important;
    text-align: center;
    padding: 0 !important;
  }
  code {
    font-size: 19px;
  }
  pre {
    font-size: 18px;
    margin: 0.2em 0;
    padding: 0.4em;
    line-height: 1.4;
  }
  h1 {
    font-size: 40px;
    margin-bottom: 0.2em;
  }
  h2 {
    font-size: 32px;
    margin-top: 0;
    margin-bottom: 0.15em;
  }
  h3 {
    font-size: 24px;
    margin: 0.1em 0;
  }
  table {
    font-size: 21px;
  }
  ul, ol {
    margin: 0.1em 0;
  }
  li {
    margin: 0.05em 0;
    line-height: 1.4;
  }
  p {
    margin: 0.2em 0;
  }
  .columns {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 0.8em;
    align-content: start;
  }
  .columns pre {
    font-size: 15px;
  }
  .columns-60-40 {
    display: grid;
    grid-template-columns: 3fr 2fr;
    gap: 0.8em;
    align-content: start;
  }
  .with-qr {
    display: grid;
    grid-template-columns: 3fr 2fr;
    gap: 2em;
    align-items: center;
    flex: 1;
  }
  .with-qr img {
    display: block;
  }
  section .with-qr > div:last-child {
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    justify-content: center;
  }
  section .with-qr > div:last-child p {
    display: flex;
    flex-direction: column;
    align-items: center;
    text-align: center;
  }
  .columns-40-60 {
    display: grid;
    grid-template-columns: 2fr 3fr;
    gap: 0.8em;
    align-content: start;
  }
---

<!-- _class: lead -->

# oauth2-passkey

&nbsp;

### Passwordless Authentication Library for Rust

### Kimitoshi Takahashi

&nbsp;

<small>Tokyo Rust Show & Tell | 2026/03/31</small>

---

<!-- _class: lead -->

# Live Demo

---

## Demo

<div class="with-qr">
<div>

1. **Google OAuth2** - First-time login with Google
2. **Passkey Promotion** - Library prompts to register fingerprint/face
3. **Passkey-only Login** - Next time, just biometrics. No redirect.
4. **Account Linking** - Both methods, same user

</div>
<div>

![w:220](../../shared/qr-demo.svg) passkey-demo.ccmp.jp


</div>
</div>

---
## Motivation

I wanted to build **exactly what you just saw** — in Rust.

- **OAuth2/OIDC**: delegate auth to trusted providers — no passwords to manage
- **Passkey**: phishing-resistant, biometrics/hardware key — no server-side secrets
- No integrated Rust/Axum library existed → built one → published to **crates.io**

---

## Agenda

1. **Using the Library**
2. **Multi-DB Storage Support**
3. **Wrap-up**

---

<!-- _class: lead -->

# Using the Library

---

## .env Setup (Minimal)

```env
ORIGIN='http://localhost:3001'

# Google OAuth2 credentials
OAUTH2_GOOGLE_CLIENT_ID='xxx.apps.googleusercontent.com'
OAUTH2_GOOGLE_CLIENT_SECRET='xxx'

# SQLite + in-memory cache (no DB setup required)
GENERIC_DATA_STORE_TYPE=sqlite
GENERIC_DATA_STORE_URL='sqlite:/tmp/auth.db'
GENERIC_CACHE_STORE_TYPE=memory
GENERIC_CACHE_STORE_URL='memory'
```

- Data store: SQLite, PostgreSQL, MySQL
- Cache store: memory, Redis

---

## How to Use

```rust
use oauth2_passkey_axum::{
    AuthUser, oauth2_passkey_full_router, // 1, Import
};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    dotenv().ok();
    oauth2_passkey_axum::init().await?;       // 2. Initialize

    let app = Router::new()
        .route("/", get(index))
        .merge(oauth2_passkey_full_router()); // 3. Merge router

    // Auth endpoints are now at /o2p/*
    spawn_http_server(3001, app).await?;
    Ok(())
}
```

Under `/o2p/*`, we have:
- OAuth2 endpoints and Passkey endpoints
- Built-in login UI, account management, and admin panel

---

## Page Protection: AuthUser Extractor

```rust
// Required auth - redirects to login if not authenticated
async fn protected(user: AuthUser) -> impl IntoResponse {
    format!("Hello, {}!", user.label)
}

// Optional auth - allows anonymous access
async fn public(user: Option<AuthUser>) -> impl IntoResponse {
    match user {
        Some(u) => format!("Hello, {}!", u.label),
        None    => "Hello, anonymous!".to_string(),
    }
}
```

Implemented via Axum's `FromRequestParts` trait:
- `AuthUser` → GET: redirect to login, others: 401
- `Option<AuthUser>` → `OptionalFromRequestParts` impl returns `None` on failure — no redirect

Limitation: always hits DB, GET always redirects. Middleware gives more control: skip DB, or return 401 even on GET.

---

## Page Protection: Middleware

Middleware gives more control: **skip DB, or return 401 even on GET.**

```rust
let app = Router::new()
    .route("/api/1", get(h1)
        .route_layer(from_fn(is_authenticated_401)))        // <-- No DB query
    .route("/api/2", get(h2)
        .route_layer(from_fn(is_authenticated_user_401)));  // <-- DB query, user info available
```
```rust
// In handler: access user or CSRF token via Extension
async fn h1(Extension(csrf): Extension<CsrfToken>) { ... }
async fn h2(Extension(user): Extension<AuthUser>) { ... }
```

---

<!-- _class: lead -->

# Storage & LazyLock Pattern

---

## Switch DB by Changing .env

```env
# SQLite (dev/demo - no setup required)
GENERIC_DATA_STORE_TYPE=sqlite
GENERIC_DATA_STORE_URL='sqlite:/tmp/auth.db'

# PostgreSQL
GENERIC_DATA_STORE_TYPE=postgres
GENERIC_DATA_STORE_URL='postgres://user:pass@localhost:5432/mydb'

# MySQL / MariaDB
GENERIC_DATA_STORE_TYPE=mysql
GENERIC_DATA_STORE_URL='mysql://user:pass@localhost:3306/mydb'

# Cache: in-memory or Redis
GENERIC_CACHE_STORE_TYPE=memory       # or: redis
GENERIC_CACHE_STORE_URL='memory'      # or: redis://localhost:6379
```

No code changes. Just swap the env vars and restart.

---

<!-- _class: lead -->

# Wrap-up

---

## Summary

- **Easy**: Add passwordless auth to your Axum app in minutes — Built-in UI included
- **Secure**: Passkey (phishing-resistant) + OAuth2, with CSRF protection and secure session cookies
- **Flexible**: Switch between SQLite, PostgreSQL, MySQL, and Redis with a single `.env` change

---

## Thank You! / Questions?

<div class="with-qr">
<div>

### About me:
- **Kimitoshi Takahashi**
- Self-employed, reskilling in Rust (3rd year)
- Let's start a startup together!

</div>
<div>

![w:200](../../shared/qr-github.svg) GitHub

![w:200](../../shared/qr-contact.svg) Contact

</div>
</div>

---

<!-- _class: lead -->

# Extra Slides

---

## What the Demo Showed

| Feature | Details |
|---------|---------|
| **OAuth2/OIDC** | Google login (also works with FedCM) |
| **Passkey Promotion** | After OAuth2 login, prompts user to register Passkey |
| **Passkey** | Google Password Manager, Apple, Windows Hello, bitwarden, Proton Pass, YubiKey |
| **Account Linking** | OAuth2 + Passkey mapped to same user |
| **Built-in UI** | Login page, account management, admin panel included |
| **Session** | Cookie-based session with CSRF protection |

All handled by a single library: `oauth2-passkey`

---

## Flow: Google Login → Passkey Setup

<div class="columns-60-40">
<div>

### Step-by-step

&nbsp;
1. **OAuth2 Login**
   ➔ Create a user in db linked with Google account
2. **Passkey Promotion**
   ➔ Register Passkey ➔ link to the user
3. **Next Login**
   ➔ Login with either Passkey or Google OAuth2

&nbsp;

One user can have multiple OAuth2 accounts and multiple passkey credentials.
</div>

<div>

### Internal Result (Linking)

&nbsp;

```text

 👤 [User] id: 1
  │
  ├── 🌐 [oauth2_accounts]
  │   ├── (Google ID)
  │   └── (GitHub ID)
  │
  └── 🔑 [passkey_credentials]
      ├── (Google Password Manager)
      ├── (Apple Password Manager)
      └── (YubiKey)

```
</div>
</div>

---

## How OAuth2/OIDC Works

<div class="columns-60-40">
<div>

![w:650](../diagrams/oauth2-flow.svg)

</div>
<div>

_Page-redirect: Google → code → id\_token → session_

</div>
</div>

---

## How Passkey/WebAuthn Works

<div class="columns-60-40">
<div>

![w:650](../diagrams/passkey-flow.svg)

</div>
<div>

_JavaScript-driven: challenge → sign → verify → session_

_Authenticators: Google Password Manager, Apple, Windows Hello, YubiKey, ..._

</div>
</div>

---

## Page Protection: Middleware Variants

| Variant | Unauthenticated | DB Query | Handler Extension |
|---------|-----------------|----------|------------------|
| `is_authenticated_401` | 401 | No | `CsrfToken` |
| `is_authenticated_user_401` | 401 | Yes | `AuthUser` |
| `is_authenticated_redirect` | Redirect to login | No | `CsrfToken` |
| `is_authenticated_user_redirect` | Redirect to login | Yes | `AuthUser` |

---

## How Multi-DB Support Works Internally

<div class="columns">
<div>

**1. LazyLock reads env at startup:**
```rust
static GENERIC_DATA_STORE: LazyLock<Mutex<Box<dyn DataStore>>>
    = LazyLock::new(|| {
        let db_type = env::var("GENERIC_DATA_STORE_TYPE");
        let db_url = env::var("GENERIC_DATA_STORE_URL");

        match db_type {
            "sqlite"   => Box::new(SqliteDataStore { pool }),
            "postgres" => Box::new(PostgresDataStore { pool }),
            "mysql"    => Box::new(MySqlDataStore { pool }),
        }
    });
```

</div>
<div>

**2. Trait + impl per backend:**
```rust
// DataStore: Send + Sync — safe to hold in a global LazyLock

impl DataStore for SqliteDataStore {
    fn as_sqlite(&self) -> Option<&Pool<Sqlite>> { Some(&self.pool) }
    fn as_postgres(&self) -> Option<&Pool<Postgres>> { None }
    fn as_mysql(&self) -> Option<&Pool<MySql>> { None }
}
```

**3. Callers dispatch via trait:**
```rust
let store = GENERIC_DATA_STORE.lock().await;
match (store.as_sqlite(), store.as_postgres(), store.as_mysql()) {
    (Some(pool), _, _) => get_all_users_sqlite(pool).await,
    (_, Some(pool), _) => get_all_users_postgres(pool).await,
    (_, _, Some(pool)) => get_all_users_mysql(pool).await,
    _ => Err(UserError::Storage("Unsupported db".into())),
}
```

</div>
</div>
&nbsp;

- `GENERIC_DATA_STORE_TYPE=sqlite` → `LazyLock` holds `SqliteDataStore`
- `SqliteDataStore` returns `(Some, None, None)` for `(as_sqlite, as_postgres, as_mysql)`
- match selects `(Some(pool), _, _)` → `get_all_users_sqlite(pool)` runs

---

## Why LazyLock Instead of Axum State?

<div class="columns">
<div>

**If the library used State:**
```rust
// User must compose AuthState into AppState
struct AppState {
    auth: AuthState,  // library's state
    pool: PgPool,     // user's own state
}
let app = Router::new().with_state(state);
```

</div>
<div>

**oauth2-passkey: LazyLock globals**
```rust
// User just calls init()
oauth2_passkey_axum::init().await?;

// Library internally:
let store = GENERIC_DATA_STORE
    .lock().await;
// No state parameter needed
```

</div>
</div>

**For users:** No need to worry about library state
**For library development:** No state threading — any function can access DB directly

---

<!-- _class: lead -->

# Integrating with Your App

---

## Integrating Your App: 1:N Schema (demo-todo)

<div class="columns">
<div>

```sql
CREATE TABLE todos (
    id        SERIAL PRIMARY KEY,
    user_id   TEXT NOT NULL,        -- FK to users.id
    title     TEXT NOT NULL,
    completed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_todos_user_id ON todos(user_id);
```

</div>
<div>

```
Your app:       Library:
┌──────────┐    ┌──────────┐
│  todos   │    │  users   │
│ user_id ─┼────┼► id (PK) │
│  title   │    └──────────┘
│ completed│    AuthUser.id
└──────────┘
  1:N todos
```

</div>
</div>

- `user_id` links to `users.id` managed by oauth2-passkey — get it from `AuthUser.id`
- Index on `user_id` is essential for efficient per-user queries
- Library DB and app DB can be the same or separate

---

## Integrating Your App: 1:N Handler (demo-todo)

<div class="columns">
<div>

```rust
// main.rs
oauth2_passkey_axum::init().await?;
let pool = db::init_db().await?;
let app = Router::new()
    .merge(todos_router())              // ← protected routes
    .with_state(AppState { pool })
    .merge(oauth2_passkey_full_router());
```

```rust
// handlers.rs
pub fn todos_router() -> Router<AppState> {
    Router::new()
        .route("/todos", get(list_todos).post(create_todo))
        .route_layer(from_fn(is_authenticated_redirect))
}
```

</div>
<div>

```rust
async fn create_todo(
    State(state): State<AppState>,
    user: AuthUser,
    Form(form): Form<TodoForm>,
) -> Result<Response, ...> {
    db::create_todo(
        &state.pool,
        &user.id,     // ──> saved as todos.user_id
        &form.title,
    ).await?;
    Ok(Redirect::to("/").into_response())
}
```

</div>
</div>

- Your `AppState` holds your own DB pool — independent from oauth2-passkey's storage
- Protect routes with middleware injecting `AuthUser` — no extra DB query at route level
- Pass `user.id` as FK when writing to your DB

---

## Integrating Your App: 1:1 Schema (demo-profile)

<div class="columns">
<div>

```sql
CREATE TABLE user_profiles (
    user_id      TEXT PRIMARY KEY,  -- PK = FK: enforces 1:1
    display_name TEXT,
    bio          TEXT,
    avatar_url   TEXT,
    theme        TEXT DEFAULT 'light',
    created_at   TIMESTAMPTZ DEFAULT NOW(),
    updated_at   TIMESTAMPTZ DEFAULT NOW()
);
```

</div>
<div>

```
Your app:            Library:
┌──────────────┐    ┌──────────┐
│ user_profiles│    │  users   │
│ user_id(PK) ─┼────┼► id (PK) │
│  display_name│    └──────────┘
│  bio         │    AuthUser.id
│  avatar_url  │
└──────────────┘
  1:1 profile
```

</div>
</div>

- `user_id TEXT PRIMARY KEY` — both PK and FK, enforces 1:1 at DB level
- No separate `id` column needed
- Profile auto-created on first login

---

## Integrating Your App: 1:1 Handler (demo-profile)

<div class="columns">
<div>

```rust
// main.rs
oauth2_passkey_axum::init().await?;
let pool = db::init_db().await?;
let app = Router::new()
    .merge(profile_router())            // ← protected routes
    .with_state(AppState { pool })
    .merge(oauth2_passkey_full_router());
```

```rust
// handlers.rs
pub fn profile_router() -> Router<AppState> {
    Router::new()
        .route("/profile", get(show_profile).post(update_profile))
        .route_layer(from_fn(is_authenticated_redirect))
}
```

</div>
<div>

```rust
async fn update_profile(
    State(state): State<AppState>,
    user: AuthUser,
    Form(form): Form<ProfileForm>,
) -> Result<Response, ...> {
    db::upsert_profile(
        &state.pool,
        &UserProfile {
            user_id: user.id.clone(), // ──> user_profiles.user_id
            bio: form.bio,
            ..Default::default()
        },
    ).await?;
    Ok(Redirect::to("/").into_response())
}
```

</div>
</div>

- Your `AppState` holds your own DB pool — independent from oauth2-passkey's storage
- Protect routes with middleware injecting `AuthUser` — no extra DB query at route level
- Pass `user.id` as FK when writing to your DB

---

## Why Not Axum State: The State Threading Problem

<div class="columns">
<div>

**With Axum State — state must flow through every layer:**
```rust
// parent doesn't use DB, but must accept State
// just to pass it down to grandchild
async fn parent(
    State(state): State<AppState>,
) -> impl IntoResponse {
    child(state).await
}

async fn child(state: AppState) -> impl IntoResponse {
    grandchild(&state).await
}

// Only grandchild actually needs DB
async fn grandchild(state: &AppState) -> impl IntoResponse {
    let users = db::get_users(&state.auth_pool).await;
    // ...
}
```

</div>
<div>

**With LazyLock — no threading needed:**
```rust
// parent and child have no idea DB exists
async fn parent() -> impl IntoResponse {
    child().await
}

async fn child() -> impl IntoResponse {
    grandchild().await
}

// grandchild accesses DB directly
async fn grandchild() -> impl IntoResponse {
    let store = GENERIC_DATA_STORE.lock().await;
    // ...
}
```

</div>
</div>

The library has 80+ internal functions. With State, all of them would need `&State` — even those that just call something else.

---

## AuthUser: FromRequestParts Implementation

<div class="columns">
<div>

```rust
impl<B> FromRequestParts<B> for AuthUser
where
    B: Send + Sync,
{
    type Rejection = AuthRedirect;

    async fn from_request_parts(
        parts: &mut Parts, _: &B,
    ) -> Result<Self, Self::Rejection> {
        let method = parts.method.clone();

        // 1. Extract session cookie
        let session_cookie = cookies
            .get(SESSION_COOKIE_NAME.as_str())
            .ok_or_else(|| AuthRedirect::new(method.clone()))?;

        // 2. Validate session → get user
        let (session_user, csrf_token) =
            get_user_and_csrf_token_from_session(...)
                .await
                .map_err(|_| AuthRedirect::new(method.clone()))?;

        Ok(AuthUser::from(session_user))
    }
}
```

</div>
<div>

```rust
// AuthRedirect: redirect on GET, 401 otherwise
impl IntoResponse for AuthRedirect {
    fn into_response(self) -> Response {
        if self.method == Method::GET {
            Redirect::temporary(LOGIN_URL).into_response()
        } else {
            (StatusCode::UNAUTHORIZED,
             "Unauthorized").into_response()
        }
    }
}
```

```rust
// Option<AuthUser>: explicit OptionalFromRequestParts
impl<B> OptionalFromRequestParts<B> for AuthUser
where
    B: Send + Sync,
{
    type Rejection = AuthRedirect;

    async fn from_request_parts(...)
        -> Result<Option<Self>, Self::Rejection>
    {
        let result =
            <AuthUser as FromRequestParts<B>>
                ::from_request_parts(parts, state).await;
        Ok(result.ok()) // Err → None, no redirect
    }
}
```

</div>
</div>

---

## What is LazyLock?

`std::sync::LazyLock` — a value initialized **once**, on first access, then shared immutably. Thread-safe. Stable since Rust 1.80.

```rust
use std::sync::LazyLock;

// Evaluated once, on first access. Never again.
static CONFIG: LazyLock<String> = LazyLock::new(|| {
    std::env::var("MY_CONFIG").expect("MY_CONFIG must be set")
});

fn anywhere() {
    println!("{}", *CONFIG);  // Just use it. No parameter needed.
}
```

Like `lazy_static!` but in std. No macro, no extra crate.

---

## LazyLock: Benefits & Trade-offs

### Benefits
- **Zero boilerplate for users** - no `AppState` struct to create
- **No state threading** - 80+ internal functions access storage directly
- **Env-only config** - switch DB by changing `.env`, no code changes
- **Fail-fast init** - `init().await?` panics on invalid env at startup

### Trade-offs
- Single instance per process (fine for auth library)
- Implicit dependencies (function signatures don't show DB access)
- Test isolation needs `#[serial]` (shared global state)

An intentional design trade-off: Rust purists would use State, but LazyLock keeps complexity inside the library.

---

## Middleware: Why Not Just Use the Extractor?

<div class="columns">
<div>

**AuthUser extractor:**
- Always redirects on auth failure
- Always fetches user from DB
- Great for web pages that need user info

**Problem:** APIs should return 401 JSON, not redirect HTML. And sometimes you just need to check "is this user logged in?" without a DB query.

</div>
<div>

**Middleware gives 2 axes of control:**

*Response type:*
- `_redirect` → Web pages (GET redirects to login)
- `_401` → APIs (always returns 401)

*Extension injected:*
- `_user` → DB query, `Extension<AuthUser>`
- Non-`_user` → No DB query, `Extension<CsrfToken>` only

```rust
// Handler with _user middleware
async fn page(
    Extension(user): Extension<AuthUser>,
) -> impl IntoResponse { ... }

// Handler with non-_user middleware
async fn api(
    Extension(csrf): Extension<CsrfToken>,
) -> impl IntoResponse { ... }
```

</div>
</div>

---

## Newtype Wrappers: Type Safety

<div class="columns">
<div>

```rust
pub struct CsrfToken(String);
pub struct UserId(String);
pub struct SessionId(String);
pub struct SessionCookie(String);
pub struct CsrfHeaderVerified(pub bool);
pub struct AuthenticationStatus(pub bool);
```

</div>
<div>

```rust
// Without newtypes - compiles but wrong!
fn check(session_id: &str, user_id: &str);
check(user_id, session_id); // Oops!

// With newtypes - compile error!
fn check(session_id: SessionId,
         user_id: UserId);
check(user_id, session_id); // Error!
```

</div>
</div>

Prevent mixing up strings/bools at compile time.

---

## Newtype Wrappers: Validation in Constructors

```rust
impl UserId {
    pub fn new(id: String) -> Result<Self, SessionError> {
        if id.is_empty() {
            return Err(SessionError::Validation("User ID cannot be empty".into()));
        }
        if id.len() > 255 {
            return Err(SessionError::Validation("User ID too long".into()));
        }
        if !id.chars().all(|c| c.is_ascii_alphanumeric()
            || matches!(c, '-' | '_' | '.' | '@' | '+')) {
            return Err(SessionError::Validation("Invalid characters".into()));
        }
        Ok(UserId(id))
    }
}
```

**If you have a `UserId`, it's guaranteed valid.** No need to re-validate.

---

## Error Hierarchy with thiserror

```rust
#[derive(Error, Debug)]
pub enum CoordinationError {
    #[error("Unauthorized access")]
    Unauthorized,
    #[error("Resource not found: {resource_type} {resource_id}")]
    ResourceNotFound { resource_type: String, resource_id: String },

    // Wrap module-specific errors
    #[error("OAuth2 error: {0}")]   OAuth2Error(OAuth2Error),
    #[error("Passkey error: {0}")]  PasskeyError(PasskeyError),
    #[error("Session error: {0}")]  SessionError(SessionError),
    #[error("User error: {0}")]     UserError(UserError),
}
```

Each module has its own error type. The coordination layer wraps them all.

---

## From Impls with Auto-Logging

<div class="columns">
<div>

```rust
impl From<OAuth2Error>
    for CoordinationError
{
    fn from(err: OAuth2Error) -> Self {
        let error = Self::OAuth2Error(err);
        tracing::error!("{}", error);
        error  // Auto-log on conversion!
    }
}
```

</div>
<div>

Every `?` that crosses a module boundary automatically logs:

```rust
// ? triggers From impl + logging
let token = exchange_code(code)
    .await?; // OAuth2Error -> logged
let user = get_user(id)
    .await?; // UserError -> logged
```

No manual `tracing::error!()` needed.

</div>
</div>

---

## Security: Constant-Time Comparison

<div class="columns">
<div>

```rust
use subtle::ConstantTimeEq;

// CSRF token verification
if header_csrf_token
    .as_bytes()
    .ct_eq(session_csrf_token
        .as_str().as_bytes())
    .into()
{
    // Token matches
}
```

</div>
<div>

**Why not just `==`?**

- Regular `==` short-circuits on first mismatch
- Attacker measures response time to guess bytes
- `ct_eq` always takes the same time

Used for CSRF tokens, session validation, and other security-sensitive comparisons.

</div>
</div>

---

## Atomic SQL: No Explicit Transactions

```rust
// "Delete user, but only if they're not the last admin"
// Done in a SINGLE SQL statement - no transaction needed

pub async fn delete_user_if_not_last_admin_postgres(
    pool: &Pool<Postgres>, id: UserId,
) -> Result<bool, UserError> {
    let result = sqlx::query(&format!(
        r#"DELETE FROM {table}
           WHERE id = $1
           AND (SELECT COUNT(*) FROM {table}
                WHERE is_admin = true) > 1"#
    ))
    .bind(id.as_str())
    .execute(pool).await?;

    Ok(result.rows_affected() > 0)
}
```

Business logic **in SQL** = atomic by default. No race conditions.

---

## SQL Dialect Differences

<div class="columns">
<div>

**PostgreSQL** - one query
```rust
sqlx::query_as::<_, User>(&format!(
    "INSERT INTO {table} (...)
     VALUES ($1, $2, ...)
     ON CONFLICT (id) DO UPDATE SET ...
     RETURNING *"
)).fetch_one(pool).await
```

</div>
<div>

**SQLite** - need two queries
```rust
sqlx::query(&format!(
    "INSERT INTO {table} (...)
     VALUES (?, ?, ...)
     ON CONFLICT (id) DO UPDATE SET ..."
)).execute(pool).await?;

sqlx::query_as::<_, User>(&format!(
    "SELECT * FROM {table} WHERE id = ?"
)).fetch_one(pool).await
```

</div>
</div>

Supporting 3 databases means handling these quirks per-backend.

---

## LazyLock Initialization Flow

**Fail-fast at Startup:** Evaluates all configs/DB immediately.
**No Axum State:** Any handler can safely access `GENERIC_DATA_STORE` globally.

<div style="text-align: center;">

![w:900 center](../diagrams/lazylock-flow.svg)

</div>

---

## Crate Structure (Detail)

![w:800 center](../diagrams/crate-structure.svg)

---

## From/Into: Clean Layer Boundaries

<div class="columns">
<div>

```rust
// DB layer -> Session layer
impl From<DbUser> for SessionUser {
    fn from(db_user: DbUser) -> Self {
        Self {
            id: db_user.id,
            account: db_user.account,
            label: db_user.label,
            is_admin: db_user.is_admin,
            ..
        }
    }
}
```

</div>
<div>

```rust
// Session -> Axum layer
impl From<SessionUser> for AuthUser {
    fn from(su: SessionUser) -> Self {
        AuthUser {
            id: su.id,
            // ... copy fields
            csrf_token: String::new(),
            session_id: String::new(),
            // ^ Axum-specific fields
        }
    }
}
```

</div>
</div>

Each layer has its own type. `From` impls make conversion seamless with `into()`.

---

## Future Plans

- **DPoP (Demonstration of Proof-of-Possession)**
  - Bind tokens to a cryptographic key
  - Prevent token theft/replay
- **Bearer Token support**
  - API authentication beyond session cookies
- **FedCM (Federated Credential Management)**
  - Browser-native identity UI (experimental, already partially implemented)
- **More OAuth2 providers**
  - GitHub, Apple, Microsoft, etc.
