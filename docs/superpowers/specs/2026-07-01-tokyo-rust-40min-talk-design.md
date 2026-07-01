# Tokyo Rust 40-Minute English Talk — Design

## Context

Possible future presentation slot at Tokyo Rust (date TBD, placeholder
2026-08-31), expanding the existing 15-minute `oauth2-passkey` talk
(`2026-03-31-tokyo-rust/talk/slides-v2-full.md`) into a 40-minute English talk.
The 15-minute deck already has a "main" section (Demo → Motivation → Agenda →
OAuth2/Passkey mechanics → Usage → Multi-DB → LazyLock → App integration →
Summary) plus an "Extra Slides" bank originally reserved for Q&A (State
threading problem, `FromRequestParts`, LazyLock deep dive, newtype wrappers,
`thiserror` hierarchy, auto-logging, constant-time comparison, CSRF, atomic
SQL, SQL dialect differences, crate structure, `From`/`Into` layers, future
plans). None of this Extra Slides content currently appears in the delivered
flow.

## Goals

- Produce a 40-minute English-language talk for Tokyo Rust.
- Reuse and extend existing English content rather than starting from
  scratch — fold the dormant "Extra Slides" bank into the main narrative.
- Add a live-coding segment building a minimal app from scratch, without
  committing to a risky all-or-nothing live demo.
- Keep the 2026-03-31 materials untouched as an accurate historical record
  of what was actually presented on that date.

## Directory & file layout

- New event directory: `2026-08-31-tokyo-rust/` (placeholder date; rename
  once the real date is confirmed).
- Slides file: `2026-08-31-tokyo-rust/talk/slides-40min.md` (the `40min`
  qualifier lives on the filename, not the directory, since the directory
  may later hold other artifacts for the same event).
- `2026-08-31-tokyo-rust/diagrams/`: seeded by copying the relevant `.mmd`
  sources (and regenerated `.svg`) from `2026-03-31-tokyo-rust/diagrams/`.
  Copy — not reference — because these diagrams are expected to be redrawn
  or extended (e.g. more detail for CSRF, atomic SQL, SQL dialect slides),
  and editing them in place would silently rewrite the 3/31 historical
  record.
- `shared/` (QR codes, contact/demo images): continue referencing in place.
  These are genuinely static cross-event assets with no reason to diverge,
  so copying them would be pure duplication.

## Content strategy

Hybrid, anchored on extending the existing flow (not a rewrite):

1. **Base**: keep the proven section order and voice of the 15-minute
   English deck.
2. **Integrate dormant Extra Slides** into the main flow instead of holding
   them in reserve — they become sections 6–7 below.
3. **Add live coding** as a new dedicated section (not a replacement for the
   opening demo) — building a minimal app from `cargo add oauth2-passkey`
   through a working login, using a **checkpoint-based** demo project: one
   git commit per step (`cargo new`, add dependency, `.env` setup, 3-line
   integration, `AuthUser` extractor, each middleware variant), each
   tagged (`step-01`, `step-02`, ...). At delivery time the presenter can
   type fully live from the current checkpoint, or `git checkout` straight
   to the next tag to skip ahead — same artifact, decided in the moment
   based on confidence and remaining time. The checkpoint project is a
   brand-new minimal example, not a modification of the existing
   `demo-todo`/`demo-profile` examples — the goal here is showing the
   "3 lines to add auth" impact from zero, not integrating into an existing
   app (that integration is still shown, condensed, in section 8).
4. Keep the opening live demo of the deployed app (passkey-demo.ccmp.jp) —
   it serves a different purpose (user-facing motivation) than the
   mid-talk live coding (developer-facing implementation), so both stay.

## Structure & timing (draft, to be tuned in rehearsal)

| # | Section | Time | Source |
|---|---------|------|--------|
| 1 | Opening: live app demo | 5 min | Existing, slightly extended (time permitting: FedCM) |
| 2 | Motivation | 1.5 min | Existing, slightly extended |
| 3 | Agenda | 0.5 min | Existing |
| 4 | How OAuth2/Passkey work | 5.5 min | Existing (registration/authentication already split in v2-full) |
| 5 | Live coding: minimal app from scratch | 11 min | New — checkpoint-based (`cargo add` → `.env` → 3-line setup → `AuthUser` extractor → middleware variants) |
| 6 | Multi-DB & LazyLock design rationale | 6.5 min | Existing + Extra Slides (State Threading Problem, LazyLock Benefits & Trade-offs) |
| 7 | Rust design patterns deep dive | 6.5 min | Extra Slides (newtype wrappers, `thiserror` hierarchy + auto-logging, constant-time comparison, CSRF, atomic SQL, SQL dialect differences) |
| 8 | App integration (demo-todo / demo-profile) | 3 min | Existing, condensed (live coding already covered the basics) |
| 9 | Future plans / crate structure | 2 min | Extra Slides (existing) |
| 10 | Summary + Thank You + QR | 2 min | Existing |

Draft total: ~44 min. Expected to be trimmed to 40 in rehearsal by cutting
within sections 6–7 first (they carry the most discretionary depth), not by
cutting the live-coding segment or the opening demo.

Remaining true Q&A reserve slides (not folded into the main flow): deeper
testing-strategy notes and any Future Plans detail that doesn't fit in
section 9. Most of the former Extra Slides bank is absorbed into the main
talk, so the reserve bank shrinks substantially from the 15-minute version.

## Language

English throughout (matches the existing `slides-v2-full.md`, unlike the
Japanese-language dev-night-tokyo deck, which is not reused here).

## Out of scope for this design

- Exact slide-by-slide content and wording within each section.
- The checkpoint project's actual code (built during implementation).
- Final rehearsal-driven timing cuts.
- Confirming the real event date (currently a placeholder).
