---
marp: true
theme: default
paginate: true
size: 16:9
style: |
  section {
    font-size: 26px;
    justify-content: flex-start;
    padding-top: 30px;
  }
  section.lead {
    justify-content: center;
    padding-top: 0;
  }
  code {
    font-size: 20px;
  }
  pre {
    font-size: 18px;
    margin: 0.3em 0;
  }
  h1 {
    font-size: 42px;
  }
  h2 {
    font-size: 34px;
    margin-bottom: 0.3em;
  }
  h3 {
    font-size: 26px;
    margin: 0.2em 0;
  }
  table {
    font-size: 22px;
  }
  ul, ol {
    margin: 0.2em 0;
  }
  li {
    margin: 0.1em 0;
  }
  p {
    margin: 0.3em 0;
  }
  .columns {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 1em;
  }
  .columns pre {
    font-size: 16px;
  }
---

<!-- _class: lead -->

# oauth2-passkey

### Passwordless Authentication Library for Rust

**@ktaka** | Tokyo Rust Show & Tell | 2026/03/31

`crates.io/crates/oauth2-passkey`
`crates.io/crates/oauth2-passkey-axum`

---

## Agenda

1. **Live Demo** - See it in action (4 min)
2. **Motivation** - Why build this? (2 min)
3. **How OAuth2 & Passkey Work** - Quick overview (2 min)
4. **Architecture & Rust Patterns** - The interesting parts (5 min)
5. **Wrap-up** - What's next & links (2 min)

---

<!-- _class: lead -->

# Live Demo

---

![bg right:25%](diagrams/qr-demo.svg)

## Demo: What We'll See

- **Passkey Registration** - Create account with fingerprint/face
- **Passkey Login** - Authenticate without password
- **Google OAuth2 Login** - Sign in with Google
- **Account Linking** - Connect OAuth2 + Passkey to same user

passkey-demo.ccmp.jp

---

## Demo: What Just Happened?

| Flow | How it works |
|------|-------------|
| **Passkey** | Browser talks to authenticator (fingerprint/YubiKey), public key stored on server |
| **OAuth2** | Redirect to Google, get authorization code, exchange for ID token |
| **Account Linking** | Both auth methods map to same user record in DB |

All handled by the `oauth2-passkey` library.

---

<!-- _class: lead -->

# Motivation

---

## Why Passwordless?

- Passwords are the #1 attack vector (phishing, reuse, breaches)
- Passkeys use **public-key cryptography** - nothing secret on the server
- **Phishing-resistant** - bound to origin (domain)
- Adoption growing fast: Google, Apple, Microsoft all support Passkeys
- OAuth2/OIDC is the standard for "Sign in with Google/GitHub/..."

---

## Why Build This Library?

- Wanted **OAuth2 + Passkey** in a single, composable library
- Existing Rust ecosystem:
  - `webauthn-rs` - WebAuthn only, great but low-level
  - Various OAuth2 crates - OAuth2 only
  - **No combined solution** that handles both + session management
- Goal: **Add auth to your Axum app in 3 lines**

---

<!-- _class: lead -->

# How OAuth2 & Passkey Work

---

## OAuth2/OIDC Flow (Google)

![w:500 center](diagrams/oauth2-flow.svg)

---

## Passkey/WebAuthn Flow

![w:500 center](diagrams/passkey-flow.svg)

Authenticators: Google Password Manager, YubiKey, Touch ID, Windows Hello

---

<!-- _class: lead -->

# Architecture & Rust Patterns

---

## Crate Structure

![w:900 center](diagrams/crate-structure.svg)

---

## Usage: 3 Lines to Add Auth

```rust
use oauth2_passkey_axum::{
    AuthUser, oauth2_passkey_full_router, init,
};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    dotenv().ok();
    oauth2_passkey_axum::init().await?;       // 1. Initialize

    let app = Router::new()
        .route("/", get(index))
        .merge(oauth2_passkey_full_router()); // 2. Merge router

    spawn_http_server(3001, app).await?;
    Ok(())
}
```

// That's it! Auth endpoints are now at /o2p/*

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
- `AuthUser` -> auto-redirect on failure
- `Option<AuthUser>` -> no redirect, `None` for anonymous

---

## Page Protection: Middleware

<div class="columns">
<div>

```rust
let app = Router::new()
    // Protect single route
    .route("/secret", get(handler)
        .route_layer(from_fn(
            is_authenticated_redirect)))
    // Protect entire group
    .nest("/api", api_router()
        .route_layer(from_fn(
            is_authenticated_user_redirect)));
```

</div>
<div>

| Middleware | Unauth | User? |
|-----------|--------|-------|
| `_401` | 401 | No |
| `_redirect` | Login | No |
| `_user_401` | 401 | Yes |
| `_user_redirect` | Login | Yes |

All prefixed with `is_authenticated`

</div>
</div>

---

## Multi-DB with sqlx: DataStore Trait

```rust
pub(crate) trait DataStore: Send + Sync {
    fn as_sqlite(&self)   -> Option<&Pool<Sqlite>>;
    fn as_postgres(&self) -> Option<&Pool<Postgres>>;
    fn as_mysql(&self)    -> Option<&Pool<MySql>>;
}

// Each backend implements the trait
impl DataStore for SqliteDataStore {
    fn as_sqlite(&self)   -> Option<&Pool<Sqlite>>   { Some(&self.pool) }
    fn as_postgres(&self) -> Option<&Pool<Postgres>>  { None }
    fn as_mysql(&self)    -> Option<&Pool<MySql>>     { None }
}
```

One trait, three implementations - no runtime downcasting needed.

---

## Multi-DB Dispatch Pattern

```rust
impl UserStore {
    pub(crate) async fn init() -> Result<(), UserError> {
        let store = GENERIC_DATA_STORE.lock().await;

        match (store.as_sqlite(), store.as_postgres(), store.as_mysql()) {
            (Some(pool), _, _) => {
                create_tables_sqlite(pool).await?;
                validate_user_tables_sqlite(pool).await?;
            }
            (_, Some(pool), _) => {
                create_tables_postgres(pool).await?;
                validate_user_tables_postgres(pool).await?;
            }
            (_, _, Some(pool)) => {
                create_tables_mysql(pool).await?;
                validate_user_tables_mysql(pool).await?;
            }
            _ => return Err(UserError::Storage("Unsupported".into())),
        }
        Ok(())
    }
}
```

Same code structure for all storage operations (users, OAuth2 accounts, passkey credentials).

---

## Why Not Axum State? LazyLock Instead

<div class="columns">
<div>

**Typical Axum State pattern:**
```rust
struct AppState { db: PgPool, cache: Redis }
let app = Router::new().with_state(state);

// EVERY handler needs State
async fn handler(
    State(s): State<AppState>
) { ... }

// 80+ internal functions need &AppState
async fn internal_fn(
    state: &AppState
) { ... }
```

</div>
<div>

**oauth2-passkey: LazyLock globals**
```rust
static GENERIC_DATA_STORE:
    LazyLock<Mutex<Box<dyn DataStore>>>
    = LazyLock::new(|| {
        match store_type {
            "sqlite"   => Box::new(...),
            "postgres" => Box::new(...),
            "mysql"    => Box::new(...),
        }
    });

// Any function can access directly
let store = GENERIC_DATA_STORE
    .lock().await;
```

</div>
</div>

---

## LazyLock: Why It Works Here

### Benefits
- **Zero boilerplate for users** - no `AppState` struct to create
- **No state threading** - internal functions access storage directly
- **Env-only config** - set `GENERIC_DATA_STORE_TYPE=postgres` in `.env`
- **Fail-fast init** - `init().await?` forces evaluation at startup

### Trade-offs
- Single instance per process (fine for auth library)
- Implicit dependencies (function signatures don't show DB access)
- Test isolation needs `#[serial]` (shared global state)

### Why not Axum State?
A library that requires users to manage `AppState` is harder to adopt.
LazyLock keeps complexity **inside** the library.

---

## LazyLock Initialization Flow

![w:800 center](diagrams/lazylock-flow.svg)

---

## Integrating with Your App's Database

<div class="columns">
<div>

**oauth2-passkey manages auth:**
- users, sessions, OAuth2 accounts, passkey credentials

**Your app manages its own data:**
- Link via `AuthUser.id` as foreign key
- Separate tables (even separate DB)

```sql
-- App's table (demo-todo)
CREATE TABLE todos (
    id SERIAL PRIMARY KEY,
    user_id TEXT NOT NULL, -- AuthUser.id
    title TEXT NOT NULL,
    completed BOOLEAN DEFAULT FALSE
);
```

</div>
<div>

**Pattern: user.id in handlers**
```rust
async fn create_todo(
    State(state): State<AppState>,
    user: AuthUser, // from oauth2-passkey
    Form(form): Form<TodoForm>,
) -> Result<Response, ...> {
    db::create_todo(
        &state.pool,
        &user.id,  // link to auth user
        &form.title,
    ).await?;
    Ok(Redirect::to("/").into_response())
}
```

See `demo-profile` (1:1) and `demo-todo` (1:N) for full examples.

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
        if id.contains("..") || id.contains("--") {
            return Err(SessionError::Validation("Dangerous sequences".into()));
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

<!-- _class: lead -->

# What's Next

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

---

## Summary

| What | Details |
|------|---------|
| **Library** | `oauth2-passkey` + `oauth2-passkey-axum` |
| **What it does** | Passkey + OAuth2 auth for Axum apps |
| **DB support** | SQLite, PostgreSQL, MySQL (via sqlx) |
| **Design** | Layered (core + framework), LazyLock globals |
| **Rust patterns** | Newtypes, thiserror hierarchy, From/Into, DataStore trait dispatch |

### Links
- **crates.io**: `oauth2-passkey`, `oauth2-passkey-axum`
- **GitHub**: github.com/ktaka-ccmp/oauth2-passkey
- **X**: @ktaka

---

<!-- _class: lead -->

# Thank You!

### Questions?

**@ktaka** on X / GitHub

---

![bg right:25%](diagrams/qr-contact.svg)

## About Me

- **@ktaka** (X / GitHub)
- Self-employed, reskilling in Rust
- Building web authentication libraries
- Third year writing Rust

ktaka.blog.ccmp.jp/p/p.html
