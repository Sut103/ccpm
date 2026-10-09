# Plan — Capture Requirements

This phase turns an idea into a structured PRD, then converts the PRD into a technical epic ready for decomposition.

---

## Writing a PRD

**Trigger**: User wants to plan a new feature, product requirement, or area of work.

### Preflight
- Check if `.claude/prds/<name>.md` already exists — if so, confirm overwrite before proceeding.
- Ensure `.claude/prds/` directory exists; create it if not.
- Feature name must be kebab-case (lowercase, letters/numbers/hyphens, starts with a letter). If not: "❌ Feature name must be kebab-case. Example: user-auth, payment-v2"

### Process

Conduct a genuine brainstorming session before writing anything. Ask the user:
- What problem does this solve?
- Who are the users affected?
- What does success look like?
- How will we know each story is done? (outcomes that can be observed and checked from outside the system)
- What's explicitly out of scope?
- What are the constraints (tech, time, resources)?

Then write `.claude/prds/<name>.md` with this frontmatter and structure:

```markdown
---
name: <feature-name>
description: <one-line summary>
status: backlog
created: <run: date -u +"%Y-%m-%dT%H:%M:%SZ">
---

# PRD: <feature-name>

## Executive Summary
## Problem Statement
## User Stories
## Acceptance Criteria
## Functional Requirements
## Non-Functional Requirements
## Success Criteria
## Constraints & Assumptions
## Out of Scope
## Dependencies
```

**User stories** get IDs: `US-1: As a <role>, I want <capability> so that <benefit>.`

**Acceptance criteria** state, per story, the observable behavior that proves it is done. They are the root of the test chain (PRD `AC` → epic `TS` → task `TC`; see `conventions.md` → TDD & Test Traceability):

```markdown
## Acceptance Criteria
- AC-1 (US-1): Given <context>, when <action>, then <observable outcome>
- AC-2 (US-1): Given <context>, when <invalid action>, then <error the user sees>
```

Write them from the user's point of view, with no implementation details (no class names, tables or endpoints).

**Quality gates before saving:**
- No placeholder text in any section
- Every user story has an ID (`US-<n>`) and at least one acceptance criterion (`AC-<n>`)
- Acceptance criteria use Given/When/Then, are observable from outside the system, and contain no implementation details
- Success criteria are measurable
- Out of scope is explicitly listed

**After creation**: Confirm "✅ PRD created: `.claude/prds/<name>.md`" and suggest: "Ready to create technical epic? Say: parse the <name> PRD"

---

## Parsing a PRD into a Technical Epic

**Trigger**: User wants to convert an existing PRD into a technical implementation plan.

### Preflight
- Verify `.claude/prds/<name>.md` exists with valid frontmatter (name, description, status, created).
- Check if `.claude/epics/<name>/epic.md` already exists — confirm overwrite if so.

### Process

Read the PRD fully, then produce `.claude/epics/<name>/epic.md`:

```markdown
---
name: <feature-name>
status: backlog
created: <run: date -u +"%Y-%m-%dT%H:%M:%SZ">
progress: 0%
prd: .claude/prds/<name>.md
github: (will be set on sync)
---

# Epic: <feature-name>

## Overview
## Architecture Decisions
## Technical Approach
### Frontend Components
### Backend Services
### Infrastructure
## Implementation Strategy
## Test Strategy
### Test Levels & Tooling
### Acceptance Test Matrix
## Task Breakdown Preview
## Dependencies
## Success Criteria (Technical)
## Estimated Effort
```

**Test Strategy** refines each PRD acceptance criterion into test scenarios:

- `### Test Levels & Tooling` — the test framework, the command that runs the full suite, and where tests live. Detect and reuse what the project already has (e.g. `package.json` scripts, `pytest.ini`, `go test`, `Cargo.toml`); propose new tooling only when none exists.
- `### Acceptance Test Matrix` — one row per scenario:

```markdown
| AC | Scenario | Level | Task |
|---|---|---|---|
| AC-1 | TS-1: valid signup creates an account and sends a welcome email | integration | Signup API |
| AC-1 | TS-2: signup form shows a confirmation after submit | e2e | Signup UI |
| AC-2 | TS-3: duplicate email is rejected with an error message | unit | Signup API |
```

Choose the lowest level that can prove the criterion; use e2e only for flows that span the whole stack. Reference tasks by name, not number: task files are renumbered on sync.

In `## Task Breakdown Preview`, list the `TS-<n>` IDs each task covers.

**Key constraints:**
- Aim for ≤10 tasks total — prefer simplicity over completeness.
- Look for ways to leverage existing functionality before creating new code.
- Identify parallelization opportunities in the task breakdown preview.
- Every PRD acceptance criterion appears in the Acceptance Test Matrix with at least one scenario, and every scenario is assigned to a task in the Task Breakdown Preview.

**After creation**: Confirm "✅ Epic created: `.claude/epics/<name>/epic.md`" and suggest: "Ready to decompose into tasks? Say: decompose the <name> epic"

---

## Editing a PRD or Epic

Read the file first, make targeted edits preserving all frontmatter. Update the `updated` frontmatter field with current datetime.

If acceptance criteria change, update the epic's Acceptance Test Matrix and the `## Test Cases` of affected tasks so the AC → TS → TC chain stays consistent.
