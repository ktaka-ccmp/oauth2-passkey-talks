# Session: Slides & Poster Setup for Tokyo Rust Show & Tell

**Date**: 2026-03-30
**Event**: Tokyo Rust Show & Tell, 2026/03/31

## Current Task

Preparing presentation materials (slides, poster, diagrams) for a 15-minute talk about the `oauth2-passkey` Rust library. Format and structure are mostly done. **Content refinement is the next priority.**

## Files Modified

### New directory structure
```
2026-03-31-tokyo-rust/
├── talk/slides-v2.md          # Main Marp slides (23 main + 13 extra)
├── talk/slides.md             # v1 slides (kept as reference)
├── talk-typst/slides.typ      # Experimental Typst slides version
├── poster/poster.typ          # A0 Typst poster
├── diagrams/*.mmd + *.svg     # 4 Mermaid diagrams
├── TALKING_POINTS.md          # Topic priorities
├── Makefile                   # Event-level build
shared/
├── qr-demo.svg               # passkey-demo.ccmp.jp
├── qr-github.svg             # github.com/ktaka-ccmp/oauth2-passkey
├── qr-contact.svg            # ktaka.blog.ccmp.jp/p/p.html
Makefile                       # Top-level (auto-detects events)
CLAUDE.md                      # Updated with full structure & tool docs
```

### Key source files
- `2026-03-31-tokyo-rust/talk/slides-v2.md` — Main presentation (Marp)
- `2026-03-31-tokyo-rust/poster/poster.typ` — A0 poster (Typst)
- `2026-03-31-tokyo-rust/talk-typst/slides.typ` — Typst slide experiment
- `2026-03-31-tokyo-rust/TALKING_POINTS.md` — Rust-specific topics with priorities
- `CLAUDE.md` — Project docs updated with directory structure & design notes

## Key Decisions

1. **Slide flow** (user's structure): Demo → Motivation (light) → Agenda → OAuth2/Passkey explanation → Library usage → Storage/LazyLock → App DB integration → Summary/About Me
2. **English** for the talk (event allows both EN/JP)
3. **Marp for slides** (with CSS workarounds for theme overrides), Typst experimental version also created
4. **Typst for poster** (A0, 2-column layout)
5. **LazyLock vs Axum State** is the highest-priority Rust-specific talking point
6. **App DB integration** (demo-profile/demo-todo) added as new content not in previous LT
7. **QR codes** positioned using CSS grid (`with-qr` class) — Marp's `bg right` and `position: absolute` don't work reliably
8. **Author name**: Kimitoshi Takahashi (@ktaka) on title slides
9. **Directory structure**: per-event directories, shared/ for cross-event assets, nested Makefiles
10. **Poster CMYK**: All colors defined as CMYK variables (`cmyk()`) for print-ready PDF output. No RGB/luma remaining. Color palette centralized in 6 variables at top of poster.typ

## Marp CSS Lessons (Critical)

- Default theme uses `div#\:\$p > svg > foreignObject > section` selector — must use `!important` on `display: flex`, `flex-flow`, `justify-content`, `padding`
- `position: absolute` and `float: right` do NOT work inside Marp's flex containers
- Use custom CSS grid classes (`with-qr`, `columns-60-40`) for layout control

## Next Steps

1. **Content refinement** — What to actually SAY on each slide (speaker notes, talking points per slide)
2. **Demo scenario** — Exact sequence, what to do if demo fails
3. **Time check** — Practice run through the 15-minute flow
4. **Slide content** — Some slides have room for more content (Motivation, Agenda are sparse)
5. **Typst slides** — Fix Passkey slide overflow (p8-9 split), polish if switching to Typst
6. **Poster QR size** — Verify scanability at A0 print size

## Context

- Source repo: `~/GitHub/oauth2-passkey` (Rust library, v0.5.1-dev)
- Previous LT: Osaki.rs 2025/03 (5 min, Japanese, 16 slides) — PDF in event directory
- Journal notes: `~/GitHub/daily-journal/ktaka/2026/0324.md` (line 975+)
- Build command: `make` from repo root builds everything
