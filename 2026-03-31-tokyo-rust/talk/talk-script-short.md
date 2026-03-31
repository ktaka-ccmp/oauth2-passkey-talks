# Talk Script: Short Version (slides-v2-short.md)

Estimated time: ~10 min (including 2 min pre-recorded demo)

---

## Slide 1: Title — oauth2-passkey

"Hi everyone. I built a passwordless authentication library for Rust called oauth2-passkey. It combines Passkey and OAuth2 and integrates with Axum. I'll cover it in 10 minutes."

---

## Slide 2: Live Demo (section lead) → play recording

"Let me start with a demo."

(Play 2-min recording: Google login → Passkey promotion → biometric login → account linking)

---

## Slide 3: Demo

"What you saw: log in with Google, the library automatically prompts Passkey registration, and from then on biometric login only — no redirect to Google. Both methods link to the same account — you can see the structure in the diagram on the right. Scan this QR if you want to try it, and please give me feedback!"

---

## Slide 4: Motivation

"Why did I build this? When I wanted to write a Rust web app, there was no library that supported both OAuth2 and Passkey with Axum integration. OAuth2 means no passwords to manage. Passkey is phishing-resistant with no server-side secrets. I wanted both, so I built it and published to crates.io."

---

## Slide 5: Agenda

"Three topics today: how to use the library, multi-DB storage support, and a wrap-up."

---

## Slide 6: Using the Library (section lead)

(transition only)

---

## Slide 7: .env Setup (Minimal)

"Configuration is just env vars: origin, Google credentials, and DB settings. For development, SQLite and in-memory cache — no DB setup. To switch to PostgreSQL in production, change env vars and restart. No code changes. Supports SQLite, PostgreSQL, MySQL, and Redis."

---

## Slide 8: How to Use

"Three steps: import, call init(), merge the router. Merging oauth2_passkey_full_router() gives you all OAuth2 and Passkey endpoints plus built-in login UI, account management, and admin panel under /o2p/*."

---

## Slide 9: Page Protection: AuthUser Extractor

"Protect a route by adding AuthUser as a handler argument. Unauthenticated requests automatically redirect or return 401. Use Option<AuthUser> for optional auth — you get None instead of a redirect. Implemented via FromRequestParts: AuthUser redirects on GET, returns 401 otherwise. Option<AuthUser> uses OptionalFromRequestParts, mapping errors to None. For finer control — skip the DB query, or return 401 even on GET — use Middleware."

---

## Slide 10: Page Protection: Middleware

"Middleware gives more control: no DB query, or 401 even on GET. Just pass a function to route_layer. is_authenticated_401, is_authenticated_user_401, and so on — pick the variant that fits."

---

## Slide 11: Storage & LazyLock Pattern (section lead)

(transition only)

---

## Slide 12: Switch DB by Changing .env

"Switching DBs is just env vars — SQLite, PostgreSQL, MySQL, Redis. No code changes at all. Internally, a LazyLock reads the env at startup, builds the right DataStore implementation, and callers dispatch through the trait. Details are in slides-v2-full.md."

---

## Slide 13: Wrap-up (section lead)

(transition only)

---

## Slide 14: Summary

"Three takeaways. Easy: init() and merge — UI included. Secure: Passkey plus OAuth2, CSRF protection, secure session cookies. Flexible: swap SQLite / PostgreSQL / MySQL / Redis by env var only."

---

## Slide 15: Thank You / Questions?

"That's it. GitHub is here. Questions welcome. Thank you."

---

## For Q&A

Switch to slides-v2-full.md for backup slides covering:
- How OAuth2 & Passkey work (flow diagrams)
- Multi-DB internals (LazyLock → DataStore → dispatch)
- Why LazyLock vs Axum State
- Integration patterns (1:N todo, 1:1 profile)
- AuthUser implementation, Newtype wrappers, Error hierarchy, etc.

See `talk-script-extra.md` for scripts for each backup slide.
