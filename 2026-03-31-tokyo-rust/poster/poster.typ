// A0 Poster: oauth2-passkey
// Compile: typst compile poster.typ --root ../..

// Color palette (CMYK for print)
#let title-color  = cmyk(72%, 47%, 0%, 64%)   // dark navy
#let line-color   = cmyk(72%, 47%, 0%, 64%)   // same as title
#let box-fill     = cmyk(0%, 0%, 0%, 1%)      // near-white bg
#let box-stroke   = cmyk(0%, 0%, 0%, 22%)     // light gray border
#let code-fill    = cmyk(0%, 0%, 0%, 4%)      // slightly darker bg
#let code-stroke  = cmyk(0%, 0%, 0%, 14%)     // code border

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
    stroke: 1pt + box-stroke,
    fill: box-fill,
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
    fill: code-fill,
    stroke: 1pt + code-stroke,
    text(font: "Noto Sans Mono", size: 15pt)[#code],
  )
}

// ============================================================
// HEADER
// ============================================================

#grid(
  columns: (1fr, 3fr, 1fr),
  gutter: 15pt,
  align: horizon,
  [],
  align(center)[
    #text(size: 64pt, weight: "bold", fill: title-color)[oauth2-passkey]
    #v(1pt)
    #text(size: 36pt)[Passwordless Authentication Library for Rust]
    #v(4pt)
    #text(size: 28pt)[
      *Kimitoshi Takahashi (\@ktaka)* #h(20pt) | #h(20pt) Tokyo Rust Show & Tell #h(20pt) | #h(20pt) 2026/03/31
    ]
  ],
  [
    #grid(
      columns: 2,
      gutter: 8pt,
      align: center,
      [
        #image("../../shared/qr-github.svg", width: 55mm)
        #text(size: 16pt)[GitHub]
      ],
      [
        #image("../../shared/qr-contact.svg", width: 55mm)
        #text(size: 16pt)[Author]
      ],
    )
  ],
)

#v(6pt)
#line(length: 100%, stroke: 2pt + line-color)
#v(8pt)

// ============================================================
// BODY - 2 column layout
// ============================================================

#grid(
  columns: (1fr, 1fr),
  gutter: 20pt,

  // ---- LEFT COLUMN ----
  [
    // Try it Yourself!
    #section-box("Try it Yourself!")[
      #grid(
        columns: (auto, 1fr),
        gutter: 20pt,
        align: horizon,
        [
          #align(center)[
            #image("../../shared/qr-demo.svg", width: 75mm)
            #text(size: 18pt, weight: "bold")[passkey-demo.ccmp.jp]
          ]
        ],
        [
          Try passwordless auth on your own device:

          + *Login with Google*
          + *Register your fingerprint* \ (Passkey Promotion — the library prompts you)
          + *Logout → Login with fingerprint only* \ No redirect, instant
          + *Check account page* \ See OAuth2 + Passkey linked to one account

          _Works with: Google Password Manager, Apple, Windows Hello, YubiKey_
        ],
      )
    ]

    #v(12pt)

    // p7: Flow: Google Login → Passkey Setup
    #section-box("Flow: Google Login → Passkey Setup")[
      #grid(
        columns: (1fr, 1fr),
        gutter: 10pt,
        [
          *Step-by-step:*
          + *OAuth2 Login* \ ➔ create user linked with Google account
          + *Passkey Promotion* \ ➔ register Passkey ➔ link to user
          + *Next Login* \ ➔ use either Passkey or Google OAuth2
        ],
        [
          *Internal DB structure:*
          #code-block[
            ```
            👤 users (id PK)
             │
             ├── 🌐 oauth2_accounts
             │    ├── Google ID
             │    └── GitHub ID
             │
             └── 🔑 passkey_credentials
                  ├── Touch ID
                  └── YubiKey
            ```
          ]
        ],
      )
      One user can have multiple OAuth2 accounts and multiple Passkey credentials.
    ]

    #v(12pt)

    // p8: How OAuth2/OIDC Works
    #section-box("How OAuth2/OIDC Works")[
      #align(center)[
        #image("../diagrams/oauth2-flow.svg", width: 85%)
      ]
      *Page-redirect based auth:*
      + User clicks "Login with Google"
      + Redirect to Google consent screen, get authorization code
      + Server exchanges code for *id_token* (JWT)
      + Extract user info, create session, set cookie
    ]

    #v(12pt)

    // p9: How Passkey/WebAuthn Works
    #section-box("How Passkey/WebAuthn Works")[
      #align(center)[
        #image("../diagrams/passkey-flow.svg", width: 85%)
      ]
      *JavaScript-driven, no redirects:*
      + Server generates *challenge*
      + Browser calls `navigator.credentials.get()`
      + Authenticator signs challenge with *private key*
      + Server verifies with stored *public key*, set cookie

      _Authenticators: Google Password Manager, YubiKey, Touch ID, Windows Hello_
    ]
  ],

  // ---- RIGHT COLUMN ----
  [
    // p11-12: Usage
    #section-box("Usage: Add Auth in 3 Steps")[
      *Step 1:* Configure `.env` (swap `sqlite` → `postgres`/`mysql` to change DB):
      #code-block[
        ```
        GENERIC_DATA_STORE_TYPE=sqlite
        GENERIC_DATA_STORE_URL='sqlite:/tmp/auth.db'
        GENERIC_CACHE_STORE_TYPE=memory
        OAUTH2_GOOGLE_CLIENT_ID='xxx.apps.googleusercontent.com'
        ```
      ]
      *Steps 2--3:* Initialize and merge router. Built-in login UI, account management, and admin panel included.
      #code-block[
        ```rust
        use oauth2_passkey_axum::{AuthUser, oauth2_passkey_full_router};

        #[tokio::main]
        async fn main() -> Result<(), Box<dyn std::error::Error>> {
            dotenv().ok();
            oauth2_passkey_axum::init().await?;       // 2. Initialize
            let app = Router::new()
                .route("/", get(index))
                .merge(oauth2_passkey_full_router()); // 3. Merge router
            spawn_http_server(3001, app).await?;
            Ok(())
        }
        ```
      ]
    ]

    #v(12pt)

    // p13-14: Page Protection
    #section-box("Page Protection")[
      *AuthUser extractor* (via `FromRequestParts`):
      #code-block[
        ```rust
        // Required auth — redirects to login if not authenticated
        async fn protected(user: AuthUser) -> impl IntoResponse { ... }

        // Optional auth — allows anonymous access
        async fn public(user: Option<AuthUser>) -> impl IntoResponse { ... }
        ```
      ]
      *Middleware* — choose 401 vs redirect, and skip DB when user info isn't needed:
      #table(
        columns: (auto, auto, auto, auto),
        inset: 7pt,
        align: left,
        table.header([*Middleware*], [*Unauth*], [*DB Query*], [*Extension*]),
        [`is_authenticated_401`], [401], [No], [`CsrfToken`],
        [`is_authenticated_redirect`], [Login], [No], [`CsrfToken`],
        [`is_authenticated_user_401`], [401], [Yes], [`AuthUser`],
        [`is_authenticated_user_redirect`], [Login], [Yes], [`AuthUser`],
      )
    ]

    #v(12pt)

    // p16-18: Storage & LazyLock
    #section-box("Storage & LazyLock Pattern")[
      *Switch DB by changing `.env` only — no code changes:*
      #code-block[
        ```
        # Data store: sqlite / postgres / mysql
        GENERIC_DATA_STORE_TYPE=sqlite
        GENERIC_DATA_STORE_URL='sqlite:/tmp/auth.db'

        # Cache store: memory / redis
        GENERIC_CACHE_STORE_TYPE=memory
        ```
      ]

      SQLite/PostgreSQL/MySQL abstracted via `DataStore` trait, held in a `LazyLock`:
      #code-block[
        ```rust
        static GENERIC_DATA_STORE: LazyLock<Mutex<Box<dyn DataStore>>>
            = LazyLock::new(|| { /* reads env, builds pool */ });

        // Dispatch — no runtime downcasting needed
        let store = GENERIC_DATA_STORE.lock().await;
        match (store.as_sqlite(), store.as_postgres(), store.as_mysql()) {
            (Some(pool), _, _) => do_sqlite(pool).await?,
            (_, Some(pool), _) => do_postgres(pool).await?,
            (_, _, Some(pool)) => do_mysql(pool).await?,
            _ => return Err(...),
        }
        ```
      ]

      *Why LazyLock instead of Axum State?*
      #grid(
        columns: (1fr, 1fr),
        gutter: 8pt,
        [
          *With Axum State:*
          - User must compose `AuthState` into their own `AppState`
          - 80+ internal library functions all need `&State`
        ],
        [
          *With LazyLock:*
          - User just calls `init().await?`
          - Any function accesses storage directly
          - Fail-fast: bad config panics at startup
        ],
      )
    ]

    #v(8pt)

    // p20-21: Integrating with Your App
    #section-box("Integrating with Your App's Database")[
      Library manages `users`, `oauth2_accounts`, `passkey_credentials`, `sessions`. Your app adds its own tables linked by `AuthUser.id`:
      #code-block[
        ```
        Library manages:           Your app adds:
        ┌──────────┐               ┌──────────────┐  ┌──────────┐
        │  users   │──AuthUser.id─>│user_profiles │  │  todos   │
        │  id (PK) │               │  user_id(FK) │  │ user_id  │
        └──────────┘               └──────────────┘  └──────────┘
                                     1:1 profile       1:N todos
        ```
      ]
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
      See `demo-profile` (1:1) and `demo-todo` (1:N) for full examples.
    ]

    #v(8pt)

    // p23: Summary + Links
    #section-box("Summary")[
      #table(
        columns: (auto, 1fr),
        inset: 8pt,
        align: left,
        [*What*], [OAuth2 + Passkey auth library for Axum],
        [*Highlights*], [Passkey Promotion, Built-in UI, Account Linking],
        [*Usage*], [`init()` + `merge(router)` + `AuthUser` extractor],
        [*Protection*], [Extractor or Middleware (401/redirect, with/without DB)],
        [*Storage*], [SQLite/PostgreSQL/MySQL + Memory/Redis, switch via `.env`],
        [*Your app*], [Link your data to `AuthUser.id`],
      )

      - *crates.io:* `oauth2-passkey`, `oauth2-passkey-axum`
      - *GitHub:* github.com/ktaka-ccmp/oauth2-passkey
      - *Demo:* passkey-demo.ccmp.jp
    ]
  ],
)
