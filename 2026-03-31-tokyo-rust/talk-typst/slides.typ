// Slides: oauth2-passkey - Tokyo Rust Show & Tell
// Compile: typst compile slides-v2.typ --root ../..

#import "@preview/polylux:0.4.0": *

#set page(paper: "presentation-16-9")
#set text(font: "Noto Sans", size: 20pt)
#show raw: set text(font: "Noto Sans Mono", size: 14pt)
#show heading.where(level: 1): set text(size: 36pt, weight: "bold", fill: rgb("#1a3a5c"))
#show heading.where(level: 2): set text(size: 28pt, weight: "bold")
#show heading.where(level: 3): set text(size: 22pt, weight: "semibold")

#let title-slide(body) = slide[
  #align(center + horizon)[#body]
]

#let section-slide(title) = slide[
  #align(center + horizon)[
    #text(size: 36pt, weight: "bold", fill: rgb("#1a3a5c"))[#title]
  ]
]

// ============================================================
// 1. Title
// ============================================================

#title-slide[
  = oauth2-passkey
  #v(8pt)
  #text(size: 24pt)[Passwordless Authentication Library for Rust]
  #v(12pt)
  #text(size: 18pt)[
    *Kimitoshi Takahashi (\@ktaka)* | Tokyo Rust Show & Tell | 2026/03/31
  ]
  #v(4pt)
  #text(size: 16pt)[
    `crates.io/crates/oauth2-passkey` #h(20pt) `crates.io/crates/oauth2-passkey-axum`
  ]
]

// ============================================================
// 2. Live Demo
// ============================================================

#section-slide[Live Demo]

// ============================================================
// 3. Demo
// ============================================================

#slide[
  == Demo

  #grid(
    columns: (1fr, auto),
    gutter: 2em,
    align: horizon,
    [
      - *Passkey Registration* - Create account with fingerprint/face
      - *Passkey Login* - Authenticate without password
      - *Google OAuth2 Login* - Sign in with Google
      - *Account Linking* - Connect OAuth2 + Passkey to same user

      passkey-demo.ccmp.jp
    ],
    [
      #image("../../shared/qr-demo.svg", width: 4cm)
    ],
  )
]

// ============================================================
// 4. What the Demo Showed
// ============================================================

#slide[
  == What the Demo Showed

  #table(
    columns: (auto, 1fr),
    inset: 8pt,
    align: left,
    table.header([*Feature*], [*Details*]),
    [*OAuth2/OIDC*], [Google login (also works with FedCM)],
    [*Passkey*], [Google Password Manager, Apple, Windows Hello, bitwarden, Proton Pass, YubiKey],
    [*Account Linking*], [OAuth2 + Passkey mapped to same user],
    [*Session*], [Cookie-based session with CSRF protection],
  )

  #v(12pt)
  All handled by a single library: `oauth2-passkey`
]

// ============================================================
// 5. Motivation
// ============================================================

#slide[
  == Motivation

  I wanted to build *exactly what you just saw* - and do it myself in Rust.

  - Existing Rust ecosystem:
    - `webauthn-rs` - WebAuthn only
    - Various OAuth2 crates - OAuth2 only
    - *No combined solution* with session management
  - So I built one. Published on *crates.io*.
]

// ============================================================
// 6. Agenda
// ============================================================

#slide[
  == Agenda

  + *How OAuth2 & Passkey Work* - What happened behind the demo
  + *Using the Library* - init, extractor, middleware
  + *Storage & LazyLock* - Multi-DB support, why not Axum State
  + *Integrating with Your App* - Linking your data to auth users
  + *Wrap-up* - Summary & links
]

// ============================================================
// 7. OAuth2/OIDC Flow
// ============================================================

#slide[
  == How OAuth2/OIDC Works

  #grid(
    columns: (3fr, 2fr),
    gutter: 1.5em,
    [
      #image("../diagrams/oauth2-flow.svg", width: 100%)
    ],
    [
      *Page-redirect based auth:*
      + User clicks "Login with Google"
      + Redirect to Google consent screen
      + Google returns authorization code
      + Server exchanges code for *id_token* (JWT)
      + Extract user info, create session
      + Set session cookie
    ],
  )
]

// ============================================================
// 8. Passkey/WebAuthn Flow
// ============================================================

#slide[
  == How Passkey/WebAuthn Works

  #grid(
    columns: (3fr, 2fr),
    gutter: 1.5em,
    [
      #image("../diagrams/passkey-flow.svg", width: 100%)
    ],
    [
      *JavaScript-driven, no redirects:*
      + Server generates *challenge*
      + Browser calls `navigator.credentials.get()`
      + Authenticator signs challenge with *private key*
      + Server verifies with stored *public key*
      + Create session, set cookie

      _Authenticators: Google Password Manager, YubiKey, Touch ID, Windows Hello_
    ],
  )
]

// ============================================================
// 9. Using the Library
// ============================================================

#section-slide[Using the Library]

// ============================================================
// 10. Setup
// ============================================================

#slide[
  == Setup: init + merge

  ```rust
  use oauth2_passkey_axum::{
      AuthUser, oauth2_passkey_full_router,
  };

  #[tokio::main]
  async fn main() -> Result<(), Box<dyn std::error::Error>> {
      dotenv().ok();
      oauth2_passkey_axum::init().await?;       // 1. Initialize

      let app = Router::new()
          .route("/", get(index))
          .merge(oauth2_passkey_full_router()); // 2. Merge router

      // Auth endpoints are now at /o2p/*
      spawn_http_server(3001, app).await?;
      Ok(())
  }
  ```
]

// ============================================================
// 11. AuthUser Extractor
// ============================================================

#slide[
  == Page Protection: AuthUser Extractor

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
]

// ============================================================
// 12. Middleware
// ============================================================

#slide[
  == Page Protection: Middleware

  #grid(
    columns: (1fr, 1fr),
    gutter: 1.5em,
    [
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
    ],
    [
      #table(
        columns: (auto, auto, auto),
        inset: 6pt,
        align: left,
        table.header([*Middleware*], [*Unauth*], [*User?*]),
        [`_401`], [401], [No],
        [`_redirect`], [Login], [No],
        [`_user_401`], [401], [Yes],
        [`_user_redirect`], [Login], [Yes],
      )

      All prefixed with `is_authenticated`
    ],
  )
]

// ============================================================
// 13. Storage & LazyLock
// ============================================================

#section-slide[Storage & LazyLock Pattern]

// ============================================================
// 14. Multi-DB
// ============================================================

#slide[
  == Multi-DB Support with sqlx

  #grid(
    columns: (1fr, 1fr),
    gutter: 1.5em,
    [
      *DataStore trait:*
      ```rust
      pub(crate) trait DataStore: Send + Sync {
          fn as_sqlite(&self)
              -> Option<&Pool<Sqlite>>;
          fn as_postgres(&self)
              -> Option<&Pool<Postgres>>;
          fn as_mysql(&self)
              -> Option<&Pool<MySql>>;
      }
      ```

      One trait, three implementations.
      No runtime downcasting needed.
    ],
    [
      *Dispatch pattern:*
      ```rust
      let store = GENERIC_DATA_STORE
          .lock().await;

      match (store.as_sqlite(),
             store.as_postgres(),
             store.as_mysql()) {
          (Some(pool), _, _) =>
              do_sqlite(pool).await?,
          (_, Some(pool), _) =>
              do_postgres(pool).await?,
          (_, _, Some(pool)) =>
              do_mysql(pool).await?,
          _ => return Err(...),
      }
      ```
    ],
  )
]

// ============================================================
// 15. LazyLock vs State
// ============================================================

#slide[
  == Why LazyLock Instead of Axum State?

  #grid(
    columns: (1fr, 1fr),
    gutter: 1.5em,
    [
      *Typical Axum State pattern:*
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
    ],
    [
      *oauth2-passkey: LazyLock globals*
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
    ],
  )
]

// ============================================================
// 16. LazyLock Benefits
// ============================================================

#slide[
  == LazyLock: Benefits & Trade-offs

  === Benefits
  - *Zero boilerplate for users* - no `AppState` struct to create
  - *No state threading* - internal functions access storage directly
  - *Env-only config* - set `GENERIC_DATA_STORE_TYPE=postgres` in `.env`
  - *Fail-fast init* - `init().await?` forces evaluation at startup

  === Trade-offs
  - Single instance per process (fine for auth library)
  - Implicit dependencies (function signatures don't show DB access)
  - Test isolation needs `#[serial]` (shared global state)

  A library that requires users to manage `AppState` is harder to adopt.
  LazyLock keeps complexity *inside* the library.
]

// ============================================================
// 17. Integrating with Your App
// ============================================================

#section-slide[Integrating with Your App]

// ============================================================
// 18. Account Linking DB
// ============================================================

#slide[
  == Account Linking: Internal DB Structure

  ```
  oauth2-passkey manages these tables:
  ┌──────────┐     ┌──────────────────┐     ┌─────────────────────┐
  │  users   │────<│  oauth2_accounts │     │ passkey_credentials │
  │          │────<│                  │     │                     │
  │  id (PK) │     │  user_id (FK)    │     │  user_id (FK)       │
  │  account │     │  provider        │     │  credential_id      │
  │  label   │     │  provider_uid    │     │  public_key         │
  └──────────┘     └──────────────────┘     └─────────────────────┘
         │
         │ user_id
         ▼
  ┌──────────────┐  ┌──────────┐
  │user_profiles │  │  todos   │    <- Your app's tables
  │  (1:1)       │  │  (1:N)   │
  └──────────────┘  └──────────┘
  ```

  One user can have multiple OAuth2 accounts AND multiple passkeys.
]

// ============================================================
// 19. App Integration
// ============================================================

#slide[
  == Your App's Data: Link via AuthUser.id

  #grid(
    columns: (1fr, 1fr),
    gutter: 1.5em,
    [
      *Setup: two databases, one app*
      ```rust
      // 1. oauth2-passkey init
      oauth2_passkey_axum::init().await?;

      // 2. App's own DB
      let pool = db::init_db().await?;
      let state = AppState { pool };

      // 3. Combine routes
      let app = Router::new()
          .route("/", get(index))
          .merge(handlers::router())
          .with_state(state)
          .merge(oauth2_passkey_full_router());
      ```
    ],
    [
      *Handler: use user.id as FK*
      ```rust
      async fn create_todo(
          State(state): State<AppState>,
          user: AuthUser,
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

      See `demo-profile` (1:1) and `demo-todo` (1:N).
    ],
  )
]

// ============================================================
// 20. Wrap-up
// ============================================================

#section-slide[Wrap-up]

// ============================================================
// 21. Summary
// ============================================================

#slide[
  == Summary

  #grid(
    columns: (1fr, auto),
    gutter: 2em,
    align: horizon,
    [
      #table(
        columns: (auto, 1fr),
        inset: 8pt,
        align: left,
        table.header([*What*], [*Details*]),
        [*Library*], [`oauth2-passkey` + `oauth2-passkey-axum`],
        [*What it does*], [Passkey + OAuth2 auth for Axum apps],
        [*DB support*], [SQLite, PostgreSQL, MySQL (via sqlx)],
        [*Key design*], [LazyLock globals, DataStore trait dispatch],
        [*Integration*], [`AuthUser.id` links your app data to auth],
      )

      === Links
      - *crates.io:* `oauth2-passkey`, `oauth2-passkey-axum`
      - *GitHub:* github.com/ktaka-ccmp/oauth2-passkey
      - *X:* \@ktaka
    ],
    [
      #align(center)[
        #image("../../shared/qr-github.svg", width: 4cm)
        GitHub
      ]
    ],
  )
]

// ============================================================
// 22. Thank You
// ============================================================

#title-slide[
  = Thank You!
  #v(8pt)
  === Questions?
  #v(4pt)
  *Kimitoshi Takahashi (\@ktaka)* on X / GitHub
]

// ============================================================
// 23. About Me
// ============================================================

#slide[
  == About Me

  #grid(
    columns: (1fr, auto),
    gutter: 2em,
    align: horizon,
    [
      - *\@ktaka* (X / GitHub)
      - Self-employed, reskilling in Rust
      - Building web authentication libraries
      - Third year writing Rust

      ktaka.blog.ccmp.jp/p/p.html
    ],
    [
      #align(center)[
        #image("../../shared/qr-contact.svg", width: 4cm)
        Contact
      ]
    ],
  )
]
