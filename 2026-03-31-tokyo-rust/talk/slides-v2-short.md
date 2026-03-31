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
  .center-content p {
    display: flex;
    flex-direction: column;
    align-items: center;
    text-align: center;
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

&nbsp;
<div class="columns-60-40">
<div>

1. Google OAuth2/OIDC Login to create a user
2. Passkey Promotion -> register
3. Login with either Passkey or Google OAuth2

<div class="center-content">

![w:220](../../shared/qr-demo.svg)

Try it out & give me feedback!

</div>

</div>
<div>

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
