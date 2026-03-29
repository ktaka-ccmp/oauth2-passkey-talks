// A0 Poster: oauth2-passkey
// Compile: typst compile poster.typ --root ../..

#set page(
  width: 841mm,
  height: 1189mm,
  margin: (x: 35mm, y: 25mm),
)

#set text(font: "Noto Sans", size: 22pt)
#show heading.where(level: 1): set text(size: 44pt, weight: "bold")
#show heading.where(level: 2): set text(size: 32pt, weight: "bold")
#show heading.where(level: 3): set text(size: 26pt, weight: "semibold")
#show raw: set text(font: "Noto Sans Mono", size: 16pt)

#let section-box(title, body) = {
  block(
    width: 100%,
    inset: 14pt,
    radius: 8pt,
    stroke: 1pt + luma(200),
    fill: luma(252),
    [
      #text(size: 30pt, weight: "bold")[#title]
      #v(6pt)
      #body
    ],
  )
}

#let code-block(code) = {
  block(
    width: 100%,
    inset: 10pt,
    radius: 6pt,
    fill: luma(245),
    stroke: 1pt + luma(220),
    text(font: "Noto Sans Mono", size: 15pt)[#code],
  )
}

// ============================================================
// HEADER
// ============================================================

#align(center)[
  #text(size: 64pt, weight: "bold", fill: rgb("#1a3a5c"))[oauth2-passkey]
  #v(4pt)
  #text(size: 36pt)[Passwordless Authentication Library for Rust]
  #v(4pt)
  #text(size: 28pt)[
    *\@ktaka* #h(20pt) | #h(20pt) Tokyo Rust Show & Tell #h(20pt) | #h(20pt) 2026/03/31
  ]
  #v(2pt)
  #text(size: 24pt)[
    `crates.io/crates/oauth2-passkey` #h(30pt) `crates.io/crates/oauth2-passkey-axum`
  ]
]

#v(10pt)
#line(length: 100%, stroke: 2pt + rgb("#1a3a5c"))
#v(10pt)

// ============================================================
// BODY - 2 column layout
// ============================================================

#grid(
  columns: (1fr, 1fr),
  gutter: 20pt,

  // ---- LEFT COLUMN ----
  [
    #section-box("What is oauth2-passkey?")[
      A Rust library that provides *OAuth2/OIDC + Passkey/WebAuthn* authentication for Axum web applications.

      - *Passkey* (WebAuthn) -- passwordless, phishing-resistant auth
      - *OAuth2/OIDC* -- "Sign in with Google" and other providers
      - *Account Linking* -- multiple auth methods, one user
      - *Session management* -- cookie-based with CSRF protection
      - Published on *crates.io*
    ]

    #v(12pt)

    #section-box("How OAuth2/OIDC Works")[
      #align(center)[
        #image("../diagrams/oauth2-flow.svg", width: 85%)
      ]
      + User clicks "Login with Google"
      + Redirect to Google, get authorization code
      + Server exchanges code for *id_token* (JWT)
      + Create session, set cookie
    ]

    #v(12pt)

    #section-box("How Passkey/WebAuthn Works")[
      #align(center)[
        #image("../diagrams/passkey-flow.svg", width: 85%)
      ]
      + Server generates *challenge*
      + Browser calls `navigator.credentials.get()`
      + Authenticator signs challenge with *private key*
      + Server verifies with stored *public key*, set cookie

      _Authenticators: Google Password Manager, YubiKey, Touch ID, Windows Hello_
    ]

    #v(12pt)

    #section-box("Multi-DB Support with sqlx")[
      SQLite, PostgreSQL, and MySQL via a single `DataStore` trait:

      #code-block[
        ```rust
        pub(crate) trait DataStore: Send + Sync {
            fn as_sqlite(&self)   -> Option<&Pool<Sqlite>>;
            fn as_postgres(&self) -> Option<&Pool<Postgres>>;
            fn as_mysql(&self)    -> Option<&Pool<MySql>>;
        }
        ```
      ]

      Dispatch via pattern matching -- no runtime downcasting:

      #code-block[
        ```rust
        match (store.as_sqlite(), store.as_postgres(), store.as_mysql()) {
            (Some(pool), _, _) => do_sqlite(pool).await?,
            (_, Some(pool), _) => do_postgres(pool).await?,
            (_, _, Some(pool)) => do_mysql(pool).await?,
            _ => return Err(...),
        }
        ```
      ]
    ]
  ],

  // ---- RIGHT COLUMN ----
  [
    #section-box("Usage: Add Auth in 3 Steps")[
      #code-block[
        ```rust
        use oauth2_passkey_axum::{AuthUser, oauth2_passkey_full_router};

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
        // 3. Protect routes with AuthUser extractor
        async fn index(user: AuthUser) -> impl IntoResponse {
            format!("Hello, {}!", user.label)
        }
        ```
      ]
    ]

    #v(12pt)

    #section-box("Page Protection")[
      *AuthUser extractor:*
      #code-block[
        ```rust
        async fn protected(user: AuthUser) -> impl IntoResponse { ... }
        async fn public(user: Option<AuthUser>) -> impl IntoResponse { ... }
        ```
      ]
      #v(4pt)
      *Middleware variants:*
      #table(
        columns: (auto, auto, auto),
        inset: 8pt,
        align: left,
        table.header([*Middleware*], [*Unauth*], [*User?*]),
        [`is_authenticated_401`], [401], [No],
        [`is_authenticated_redirect`], [Login], [No],
        [`is_authenticated_user_401`], [401], [Yes],
        [`is_authenticated_user_redirect`], [Login], [Yes],
      )
    ]

    #v(12pt)

    #section-box("Why LazyLock Instead of Axum State?")[
      #grid(
        columns: (1fr, 1fr),
        gutter: 10pt,
        [
          *Typical Axum State:*
          #code-block[
            ```rust
            struct AppState { db: PgPool }
            let app = Router::new()
                .with_state(state);
            // Every handler + 80+ internal
            // functions need &AppState
            ```
          ]
        ],
        [
          *oauth2-passkey: LazyLock*
          #code-block[
            ```rust
            static GENERIC_DATA_STORE:
              LazyLock<Mutex<Box<dyn DataStore>>>
              = LazyLock::new(|| { ... });
            // Any function accesses directly
            let store = GENERIC_DATA_STORE
                .lock().await;
            ```
          ]
        ],
      )
      - *Zero boilerplate* -- no `AppState` for users
      - *Env-only config* -- set `DB_TYPE=postgres` in `.env`
      - *Fail-fast init* -- `init().await?` catches errors at startup
    ]

    #v(8pt)

    #section-box("Integrating with Your App's Database")[
      Link your app data to auth users via `AuthUser.id`:
      #code-block[
        ```rust
        async fn create_todo(
            State(state): State<AppState>,
            user: AuthUser, // from oauth2-passkey
            Form(form): Form<TodoForm>,
        ) -> Result<Response, ...> {
            db::create_todo(&state.pool, &user.id, &form.title).await?;
            Ok(Redirect::to("/").into_response())
        }
        ```
      ]
      See `demo-profile` (1:1) and `demo-todo` (1:N) for examples.
    ]

    #v(8pt)

    #section-box("Links")[
      #grid(
        columns: (1fr, auto, auto, auto),
        gutter: 12pt,
        align: horizon,
        [
          - *crates.io:* `oauth2-passkey`, `oauth2-passkey-axum`
          - *GitHub:* github.com/ktaka-ccmp/oauth2-passkey
          - *X:* \@ktaka
        ],
        [
          #align(center)[
            #image("../../shared/qr-demo.svg", width: 40mm)
            #text(size: 16pt)[Demo]
          ]
        ],
        [
          #align(center)[
            #image("../../shared/qr-github.svg", width: 40mm)
            #text(size: 16pt)[GitHub]
          ]
        ],
        [
          #align(center)[
            #image("../../shared/qr-contact.svg", width: 40mm)
            #text(size: 16pt)[Contact]
          ]
        ],
      )
    ]
  ],
)
