# Structure — Break Down an Epic

This phase converts a technical epic into concrete, numbered task files with dependency and parallelization metadata.

---

## Epic Decomposition

**Trigger**: User wants to break an epic into actionable tasks.

### Preflight
- Verify `.claude/epics/<name>/epic.md` exists with valid frontmatter.
- If numbered task files (001.md, 002.md...) already exist in the epic directory, list them and confirm deletion before recreating.
- If epic status is "completed", warn the user before proceeding.

### Process

Read the epic fully. Analyze for parallelism — which pieces of work can happen simultaneously without file conflicts?

**Task types to consider:**
- Setup: environment, scaffolding, dependencies
- Data: models, schemas, migrations
- API: endpoints, services, integration
- UI: components, pages, styling
- Docs: README, API docs, changelogs

Tests are not a separate task type: each task writes the tests for its own behavior first (see `conventions.md` → TDD & Test Traceability). Cover every test scenario (`TS-<n>`) in the epic's Acceptance Test Matrix in the task that implements that behavior. An e2e scenario that spans several tasks goes to the task that completes the flow (usually the last one in the dependency chain). If the epic plans a Setup task that introduces test tooling, every other task lists it in `depends_on`.

**Parallelization strategy by epic size:**
- Small (<5 tasks): create sequentially
- Medium (5–10 tasks): batch into 2–3 groups, spawn parallel Task agents
- Large (>10 tasks): analyze dependencies first, launch parallel agents (max 5 concurrent), create dependent tasks after prerequisites

For parallel creation, use the Task tool:
```yaml
Task:
  description: "Create task files batch N"
  subagent_type: "general-purpose"
  prompt: |
    Create task files for epic: <name>
    Tasks to create: [list 3-4 tasks, with the TS IDs each covers]
    Save to: .claude/epics/<name>/001.md, 002.md, etc.
    Follow the task file format exactly, including concrete Test Cases for every assigned TS.
    Return: list of files created.
```

### Task File Format

```markdown
---
name: <Task Title>
status: open
created: <run: date -u +"%Y-%m-%dT%H:%M:%SZ">
updated: <same as created>
github: (will be set on sync)
depends_on: []
parallel: true
conflicts_with: []
---

# Task: <Task Title>

## Description

## Acceptance Criteria
- [ ] AC-<n>: <PRD criterion this task satisfies, fully or in part>
<!-- or, for a task with no PRD criterion: AC: n/a (<reason>), with Covers n/a (<reason>) -->

## Test Cases
| ID | Covers | Level | Given / When / Then | Test location |
|---|---|---|---|---|
| TC-1 | TS-<n> (AC-<n>) | unit | Given <precondition>, when <input/action>, then <expected output> | <path/to/test_file> |

## Technical Details

## Dependencies

## Effort Estimate
- Size: XS/S/M/L/XL
- Hours: N

## Definition of Done
- [ ] Test cases written first and confirmed failing for the expected reason (Red)
- [ ] Minimal implementation makes all test cases pass (Green)
- [ ] Code refactored with all tests still passing (Refactor)
- [ ] Closing gate passes (`conventions.md` → Test Gates; applies to N/A tasks too)
- [ ] Code reviewed
```

**Test Cases** are the most concrete level of the test chain (PRD `AC` → epic `TS` → task `TC`). Write them now, before any code exists; the executing agent turns them into failing tests first. Follow `conventions.md` → Writing Test Cases. For a task with no testable behavior, replace the table with `N/A — <reason>` and mark the TDD items in Definition of Done as N/A (see `conventions.md` → Exceptions).

**Quality gates before saving tasks:**
- Every `TS-<n>` in the epic's Acceptance Test Matrix appears in the `Covers` column of at least one task's test case; no scenario is left uncovered.
- Each test case has a concrete input and expected output; no wording like "works correctly".
- `## Test Cases` is never empty: it holds test cases or `N/A — <reason>`.

**Numbering**: sequential 001.md, 002.md, etc. Tasks are renamed to GitHub issue numbers after sync — do not hard-code dependencies by filename, use the `depends_on` array.

### After Creating All Tasks

Append a summary to the epic file:

```markdown
## Tasks Created
- [ ] 001.md - <Title> (parallel: true/false)
- [ ] 002.md - <Title> (parallel: true/false)

Total tasks: N
Parallel tasks: N
Sequential tasks: N
Test cases: N (test scenarios covered: N/N)
Estimated total effort: N hours
```

**After completion**: Confirm "✅ Created N tasks for epic: <name>" and suggest: "Ready to push to GitHub? Say: sync the <name> epic"

---

## Dependency Rules
- `depends_on` lists task numbers that must complete before this task can start.
- `parallel: true` means the task can run concurrently with others it doesn't conflict with.
- `conflicts_with` lists tasks that touch the same files — these cannot run in parallel.
- Circular dependencies are an error — check before finalizing.
