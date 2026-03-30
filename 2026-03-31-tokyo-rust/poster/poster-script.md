# oauth2-passkey — Poster Script

Situation: standing next to the poster, explaining to people who come by.
Estimated time: 2–3 minutes for the full script; skip/expand sections based on audience interest.

---

## [Opening]

Hi! This is `oauth2-passkey` — a passwordless authentication library for Rust and Axum.

The idea is simple: instead of managing passwords, your users log in with Google OAuth2 the first time, and the library then prompts them to register a Passkey — fingerprint, face ID, or a hardware key like YubiKey. After that, they can skip Google entirely and just use biometrics. It's faster and more secure.

I built this because I wanted to add this kind of auth to my own Axum app, and there was nothing in the Rust ecosystem that did it all in one place.

---

## [Try it Yourself]

Before I explain anything, you can try it right now. Scan this QR code — it's a live demo running on passkey-demo.ccmp.jp.

Everyone gets admin access so you can see all the features. Privacy is masked so you won't see real data. And it's ephemeral — data resets on restart, so don't worry about leaving anything behind.

Try logging in with Google, then register a Passkey when prompted. Then log out and log back in using just your fingerprint. That's the whole flow.

---

## [Motivation]

So why build this?

OAuth2 is great — you delegate authentication to a trusted provider like Google, so you never store passwords. But it requires a redirect to Google every time, which is a bit clunky.

Passkeys are even better — they're phishing-resistant because the credential is bound to the origin, and authentication happens locally via biometrics or a hardware key. There's no server-side secret to steal.

The problem was that in the Rust ecosystem, `webauthn-rs` handles Passkeys only, and there are various OAuth2 crates — but nothing that combines both with session management and a built-in UI. So I built it and published it to crates.io.

---

## [Flow: Google Login → Passkey Setup]

Here's the typical flow the library enables.

First time: the user logs in with Google OAuth2. The library creates a user record linked to their Google account.

Then comes "Passkey Promotion" — the library automatically prompts the user to register a Passkey. They tap their fingerprint, and the Passkey is linked to the same user.

Next time: they can log in with either Google or their Passkey. Both authenticate as the same user.

And the DB structure reflects this — one `users` record can have multiple OAuth2 accounts linked to it — Google, GitHub, whatever — and multiple Passkey credentials — Touch ID, YubiKey, Windows Hello.

---

## [How OAuth2/OIDC Works]

Quickly, for those not familiar — OAuth2 is page-redirect based.

The user clicks "Login with Google", gets redirected to Google's consent screen, logs in there, and Google sends back an authorization code. The server exchanges that code for an id_token — which is a JWT containing the user's identity. The server verifies it, creates a session, and sets a cookie.

The key point is: the user's browser leaves your site and comes back. That's the "page-redirect" part.

---

## [How Passkey/WebAuthn Works]

Passkey is completely different — it's JavaScript-driven, no redirects at all.

The server generates a random challenge and sends it to the browser. JavaScript calls `navigator.credentials.get()`, which asks the authenticator — your fingerprint sensor, Face ID, YubiKey — to sign the challenge with a private key stored on the device. The signed response comes back, and the server verifies it against the public key it stored during registration.

The private key never leaves the device. And because the credential is bound to your domain, it won't work on a phishing site even if the user gets tricked into visiting one.

---

## [Usage: Add Auth in 3 Steps]

Using the library is three steps.

Step 1: configure `.env`. You set the database type — SQLite for dev, PostgreSQL or MySQL for production — and your Google OAuth2 client ID. You can literally switch databases by changing one line.

Step 2: call `oauth2_passkey_axum::init().await?` at startup. This initializes the DB schema, validates config, and wires everything up.

Step 3: merge `oauth2_passkey_full_router()` into your Axum router. That's it — you now have login pages, account management, and an admin panel, all built in.

---

## [Page Protection]

There are two ways to protect routes.

The simplest is the `AuthUser` extractor. Add it as a parameter to your handler, and Axum automatically checks the session. If the user isn't authenticated, they get redirected to the login page. `Option<AuthUser>` allows anonymous access.

For more control — especially for API endpoints — you use the middleware variants. The key choice is: do you want a 401 response or a redirect on auth failure? And do you need the user's full info from the DB, or just a CSRF token?

This table shows all four combinations. For example, `is_authenticated_401` returns 401 and skips the DB — ideal for stateless API endpoints.

---

## [Storage & LazyLock Pattern]

The library supports SQLite, PostgreSQL, MySQL, and Redis. You switch between them with a single `.env` change — no code changes at all. SQLite is great for dev because there's no setup, and you can move to PostgreSQL for production by just updating the env var.

Internally, the storage is held in a `LazyLock` global rather than Axum State. The reason is pragmatic: the library has 80+ internal functions that need DB access. If we used Axum State, every one of them would need a `&State` parameter, and users would have to compose `AuthState` into their `AppState`. With `LazyLock`, you just call `init()` and everything is wired up.

The trade-off is one instance per process, and tests need `#[serial]` to avoid sharing state. That's a reasonable price for the simplicity.

---

## [Integrating with Your App's Database]

Once you have auth working, you'll want to link your own data to your users.

The pattern is simple: your app creates its own tables with a `user_id` foreign key pointing to the `users` table managed by the library. You get `user.id` from the `AuthUser` extractor in your handler, and use it as the FK when inserting records.

For example, a todo app: `todos.user_id` references `users.id`. A 1:N relationship. Or a user profile: `user_profiles.user_id` is the primary key — a 1:1 relationship that enforces one profile per user at the database level.

Your app manages its own DB pool entirely independently. The library handles auth; you handle your data.

---

## [Close]

So to summarize — Easy: three lines to add auth. Secure: Passkeys are phishing-resistant, plus CSRF protection and secure session cookies. Flexible: swap your database with a single `.env` change.

The crates are `oauth2-passkey` and `oauth2-passkey-axum` on crates.io. GitHub link and my contact are in the QR codes up there.

And if any of this sounds like something you'd want to build on or work on together — let's start a startup!
