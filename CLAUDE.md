# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Presentation preparation repository for the **Tokyo Rust Show & Tell** (2026/03/31). The talk covers the `oauth2-passkey` Rust library — a Passkey (WebAuthn) + OAuth2 authentication library built with Axum.

- **This repo**: slides, outlines, and planning docs (no source code)
- **Source repo**: `~/GitHub/oauth2-passkey` (the actual Rust library)
- **Slide tool**: Marp (Markdown to slides)
- **Languages**: content may be in Japanese or English

## Key Files

- `CONTEXT.md` — event info, presentation outlines (15-min and 5-min formats), demo plan, audience hooks

## Slides (Marp)

Marp converts Markdown files to HTML/PDF slides. Common commands:

```bash
# Preview slides with live reload
npx @marp-team/marp-cli --preview slides.md

# Export to HTML
npx @marp-team/marp-cli slides.md -o slides.html

# Export to PDF
npx @marp-team/marp-cli slides.md --pdf -o slides.pdf
```

## Workflow Tools

### Available Commands

| Command | Description |
|---------|-------------|
| `/snapshot` | Create a session snapshot for context transfer between machines |
| `/issue` | Create or update an issue for task/bug tracking |
| `/backlog` | View all open issues |

### Issue Tracking (`.claude/issues/`)

- **Filename**: `YYYYMMDD-HHMM-<short-slug>.md`
- **Status**: `open`, `completed`, `wontfix`, `deferred`
- **Priority**: `high`, `medium`, `low`
- **Format & Rules**: See `.claude/issues/README.md`
