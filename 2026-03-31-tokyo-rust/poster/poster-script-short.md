# oauth2-passkey — Poster Script (Short)

Situation: standing next to the poster, explaining to people who come by.
Estimated time: 2–3 minutes.

---

## [Opening]

Hi! This is `oauth2-passkey` — a passwordless authentication library for Rust and Axum. It combines OAuth2 login with Passkey, so your users can sign in with Google first, then switch to fingerprint or face ID for future logins.

---

## [Try it Yourself]

You can try it right now — scan this QR code. Everyone gets admin access, privacy is masked, and data resets on restart, so feel free to poke around.

---

## [Motivation]

I wanted both OAuth2 and Passkey in one library with session management. The Rust ecosystem had `webauthn-rs` for Passkey-only and various OAuth2 crates — but nothing combined. So I built one and published it to crates.io.

---

## [Flow]

The typical flow is: first login with Google OAuth2, then the library prompts the user to register a Passkey. From then on, they can use either. One user can link multiple OAuth2 accounts and multiple Passkey credentials.

---

## [How OAuth2 Works]

OAuth2 is page-redirect based — the browser goes to Google, gets an authorization code, the server exchanges it for an id_token, extracts the user info, and sets a session cookie.

---

## [How Passkey Works]

Passkey is JavaScript-driven — no redirects. The server sends a challenge, the browser calls `navigator.credentials.get()`, the authenticator signs it with a private key, and the server verifies with the stored public key.

---

## [Usage]

To add auth to your app: configure `.env` with your DB and Google client ID, call `init().await?`, and merge `oauth2_passkey_full_router()`. That's it — login UI, account management, and admin panel are all built in.

---

## [Page Protection]

To protect a page, just add `AuthUser` as an extractor. For APIs that need 401 instead of a redirect, use the middleware variants. You can also skip the DB query if you only need CSRF protection.

---

## [Storage & LazyLock]

The library supports SQLite, PostgreSQL, MySQL, and Redis — you switch between them by changing a single `.env` variable, no code changes. Internally it uses a `LazyLock` global instead of Axum State, so you just call `init()` and the library handles everything. The trade-off is one instance per process and `#[serial]` in tests.

---

## [Integration]

Your app adds its own tables linked by `AuthUser.id`. Pass `user.id` as a foreign key and you're done. The library manages auth; your app manages your data.

---

## [Close]

So — Easy, Secure, Flexible. The crates are `oauth2-passkey` and `oauth2-passkey-axum` on crates.io. And if this sounds interesting to work on together — let's start a startup!
