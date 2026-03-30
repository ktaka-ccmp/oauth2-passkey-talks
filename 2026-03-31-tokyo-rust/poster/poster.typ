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
#show heading.where(level: 1): set text(size: 45pt, weight: "bold")
#show heading.where(level: 2): set text(size: 33pt, weight: "bold")
#show heading.where(level: 3): set text(size: 27pt, weight: "semibold")
#show raw: set text(font: "Noto Sans Mono", size: 18pt)

#let section-box(title, body) = {
  block(
    width: 100%,
    inset: 14pt,
    radius: 8pt,
    stroke: 1pt + box-stroke,
    fill: box-fill,
    [
      #text(size: 31pt, weight: "bold")[#title]
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
    {
      set par(leading: 0.8em)
      text(font: "Noto Sans Mono", size: 18pt)[#code]
    },
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
      *Kimitoshi Takahashi* #h(20pt) | #h(20pt) Tokyo Rust Show & Tell #h(20pt) | #h(20pt) 2026/03/31
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
        columns: (9fr, 10fr, 10fr),
        gutter: 20pt,
        align: horizon,
        [
          #align(center)[
            #image("../../shared/qr-demo.svg", width: 76mm)
            #text(size: 18pt, weight: "bold")[passkey-demo.ccmp.jp]
          ]
        ],
        [
          #align(center)[
            #image("../../shared/passkey.demo.cropped.png", width: 80mm)
            #text(size: 18pt, weight: "bold")[ Give it a try & tell me your thoughts!]
          ]
        ],
        [
          #[
            #set list(spacing: 1em)
            - _Admin access granted to all_
            - _Privacy masked_
            - _Ephemeral: data resets on restart_
          ]
        ],
      )
    ]

    #v(10pt)

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

    #v(10pt)

    // p8: How OAuth2/OIDC Works
    #section-box("How OAuth2/OIDC Works")[
      #align(center)[
        #image("../diagrams/oauth2-flow.svg", width: 96%)
      ]
      _Page-redirect: Google → code → id\_token → session_
    ]

    #v(10pt)

    // p9: How Passkey/WebAuthn Works
    #section-box("How Passkey/WebAuthn Works")[
      #align(center)[
        #image("../diagrams/passkey-flow.svg", width: 96%)
      ]
      _JavaScript-driven: challenge → sign → verify → session_
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
      *Steps 2--3:* Initialize and merge router — login UI, account mgmt & admin panel built-in.
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

    #v(10pt)

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
      #grid(
        columns: (5fr, 3fr),
        gutter: 10pt,
        align: top,
        [
          #code-block[
            ```rust
            let app = Router::new()
                .route("/api/1", get(h1)
                    .route_layer(from_fn(is_authenticated_401)))
                .route("/api/2", get(h2)
                    .route_layer(from_fn(is_authenticated_user_401)));

            async fn h1(Extension(csrf): Extension<CsrfToken>) { ... }
            async fn h2(Extension(user): Extension<AuthUser>) { ... }
            ```
          ]
        ],
        [
          #v(4pt)
          #text(weight: "bold")[`is_authenticated_{Variant}`]
          #v(6pt)
          #table(
            columns: (auto, auto, auto, auto),
            inset: 7pt,
            align: left,
            table.header([*Variant*], [*Error*], [*DB?*], [*Ext.*]),
            [`401`], [401], [No], [`CsrfToken`],
            [`user_401`], [401], [Yes], [`AuthUser`],
            [`redirect`], [Login], [No], [`CsrfToken`],
            [`user_redirect`], [Login], [Yes], [`AuthUser`],
          )
        ],
      )
    ]

    #v(10pt)

    // p16-18: Storage & LazyLock
    #section-box("Storage & LazyLock Pattern")[
      *Switch DB by changing `.env` only — no code changes:*
      #grid(
        columns: (11fr, 7fr),
        gutter: 10pt,
        [
          #code-block[
            ```
            # Data store (pick one):
            GENERIC_DATA_STORE_TYPE=sqlite
            GENERIC_DATA_STORE_URL='sqlite:/tmp/auth.db'

            GENERIC_DATA_STORE_TYPE=postgres
            GENERIC_DATA_STORE_URL='postgres://id:pw@host:5432/db'

            GENERIC_DATA_STORE_TYPE=mysql
            GENERIC_DATA_STORE_URL='mysql://id:pw@host:3306/db'
            ```
          ]
        ],
        [
          #code-block[
            ```
            # Cache store (pick one):
            GENERIC_CACHE_STORE_TYPE=memory

            GENERIC_CACHE_STORE_TYPE=redis
            GENERIC_CACHE_STORE_URL=
                           'redis://host:6379'
            ```
          ]
        ],
      )

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
      - *Axum State*: user composes `AppState`; 80+ internal fns all need `&State`
      - *LazyLock*: just `init()` — globals accessed directly; fail-fast at startup
    ]

    #v(8pt)

    // p20-21: Integrating with Your App
    #section-box("Integrating with Your App's Database")[
      Your app adds its own tables linked by `AuthUser.id`:
      #grid(
        columns: (3fr, 2fr),
        gutter: 10pt,
        align: top,
        [
          #code-block[
            ```rust
            async fn create_todo(
                State(state): State<AppState>,
                user: AuthUser, // from oauth2-passkey
                Form(form): Form<TodoForm>,
            ) -> Result<Response, ...> {
                db::create_todo(
                  &state.pool,
                  &user.id, // ──> todos.user_id
                  &form.title
                ).await?;
                Ok(Redirect::to("/").into_response())
            }
            ```
          ]
        ],
        [
          #code-block[
            ```
            Library:        Your app:           
            ┌──────────┐    ┌──────────┐
            │  users   │    │  todos   │
            │ id (PK) ─┼────┼► user_id │
            └──────────┘    │  title   │
            AuthUser.id     └──────────┘
                             1:N todos
            ```
          ]
        ],
      )
    ]

  ],
)

// ============================================================
// FOOTER - Full width Summary
// ============================================================

#v(12pt)
#section-box("Summary")[
  #grid(
    columns: (3fr, 2fr),
    gutter: 20pt,
    [
      #set list(spacing: 0.8em)
      - *Library*: OAuth2 + Passkey/WebAuthn auth for Axum; Passkey Promotion, Built-in UI, Account Linking
      - *Setup*: `init().await?` + `merge(oauth2_passkey_full_router())` — 3 lines to add auth
      - *Protect*: `AuthUser` extractor or `is_authenticated_*` middleware (401/redirect, ±DB query)
      - *Storage*: SQLite/PostgreSQL/MySQL + Memory/Redis — switch via `.env`, no code changes
      #v(18pt)
    ],
    [
      - *crates.io:* `oauth2-passkey`, `oauth2-passkey-axum`
      - *GitHub:* github.com/ktaka-ccmp/oauth2-passkey
      - *Demo:* passkey-demo.ccmp.jp
    ],
  )
]
