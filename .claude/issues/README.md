# Issue Tracking

This directory contains issue/task tracking files for the project.

## Current Issues

<!-- AUTO-UPDATED: Do not edit manually. Updated by /issue command. -->

### Open (0)

| ID | Priority | Difficulty | Title |
|----|----------|------------|-------|

### Completed (0)

| ID | Title |
|----|-------|

### Wontfix (0)

| ID | Title |
|----|-------|

### Deferred (0)

| ID | Title |
|----|-------|

<!-- END AUTO-UPDATED -->

## Directory Structure

```
.claude/issues/
├── open/           # Active issues
├── completed/      # Resolved issues
├── wontfix/        # Closed without implementation
├── deferred/       # Postponed issues
└── README.md       # This file
```

Issues are organized by status. When status changes, move the file to the appropriate directory.

## File Naming Convention

New issues use the timestamp-based format:

```text
YYYYMMDD-HHMM-<short-slug>.md
```

Example: `20260210-1430-login-history-enhancement.md`

## Issue ID Format

New issues use a timestamp-based ID:

```text
YYYYMMDD-HHMM
```

- `YYYYMMDD`: Creation date
- `HHMM`: Creation time (24h format)

Example: `20260210-1430`, `20260210-1545`

## Issue Template

```markdown
# Issue: <Title>

## Table of Contents

- [Description](#description)
- [Related Issues](#related-issues)
- [Approach](#approach)
- [Related Files](#related-files)
- [Implementation Tasks](#implementation-tasks)
- [Decision Log](#decision-log)
- [Resolution](#resolution)

## ID: YYYYMMDD-HHMM

## Created: YYYY-MM-DD-HH-MM

## Closed:

## Status: open | completed | wontfix | deferred

## Priority: high | medium | low

## Difficulty: small | medium | large

## Description

<What needs to be done and why>

## Related Issues

- `YYYYMMDD-HHMM` <Title> (relationship: e.g., depends on, related to, supersedes)

## Approach

<Current plan for implementation>

## Related Files

- `path/to/file`

## Implementation Tasks

- [ ] <Task 1>
- [ ] <Task 2>

## Decision Log

<!-- APPEND-ONLY: Do not edit or delete existing entries. Add new entries at the bottom. -->

### YYYY-MM-DD: <Short summary of decision>

- Context: <What prompted this decision>
- Decision: <What was decided>
- Reason: <Why this was chosen over alternatives>

## Resolution

<What was done to resolve this issue>
```

## Section Update Rules

| Section | Update Rule |
|---------|------------|
| Created | Written once at creation |
| Closed | Written once when issue is resolved or closed |
| Description | Freely updatable |
| Related Issues | Freely updatable |
| Approach | Freely updatable (always reflects current plan) |
| Related Files | Freely updatable |
| Implementation Tasks | Freely updatable |
| **Decision Log** | **Append-only -- never edit or delete existing entries** |
| Resolution | Written once when issue is resolved |

The **Decision Log** preserves the history of design decisions, approach changes, and
rejected alternatives. When updating other sections (especially Approach), always add
a corresponding Decision Log entry explaining what changed and why.

## Status Values

| Status | Directory | Description |
|--------|-----------|-------------|
| `open` | `open/` | New or in-progress |
| `completed` | `completed/` | Resolved and committed |
| `wontfix` | `wontfix/` | Closed without implementation |
| `deferred` | `deferred/` | Postponed for later |

## Commands

- `/issue` - Create or update an issue
- `/backlog` - View all open issues
- `/snapshot` - Create a session snapshot (different from issues)

## Workflow

1. Create new issue in `open/` directory
2. **Update this README's "Current Issues" table** (increment count, add row)
3. Work on the issue
4. When resolved, update Resolution section and move to `completed/`
5. If postponed, move to `deferred/`

**Important**: Always update the README table when creating, completing, or moving issues.

## Difference from Sessions

- **Sessions** (`.claude/sessions/`): Work context snapshots for transferring between machines
- **Issues** (`.claude/issues/`): Task/bug tracking that persists across sessions