# Execute — Start Building with Parallel Agents

This phase covers analyzing GitHub issues for parallel work streams and launching agents to execute them.

All `gh` commands in this phase follow the availability/fallback rule in conventions.md § Authentication & MCP Fallback.

---

## Issue Analysis

**Trigger**: User wants to understand how to parallelize work on an issue before starting.

### Preflight
- Find the local task file: check `.claude/epics/*/<N>.md` first, then search for `github:.*issues/<N>` in frontmatter.
- If not found: "❌ No local task for issue #<N>. Run a sync first."

### Process

Get issue details: `gh issue view <N> --json title,body,labels`

Read the local task file fully. Identify independent work streams by asking:
- Which files will be created/modified?
- Which changes can happen simultaneously without conflict?
- What are the dependencies between changes?

**Common stream patterns:**
- Database Layer: schema, migrations, models
- Service Layer: business logic, data access
- API Layer: endpoints, validation, middleware
- UI Layer: components, pages, styles
- Test Layer: unit tests, integration tests

Create `.claude/epics/<epic_name>/<N>-analysis.md`:

```markdown
---
issue: <N>
title: <title>
analyzed: <run: date -u +"%Y-%m-%dT%H:%M:%SZ">
estimated_hours: <total>
parallelization_factor: <1.0-5.0>
---

# Parallel Work Analysis: Issue #<N>

## Overview

## Parallel Streams

### Stream A: <Name>
**Scope**: 
**Files**: 
**Can Start**: immediately
**Estimated Hours**: 
**Dependencies**: none

### Stream B: <Name>
**Scope**: 
**Files**: 
**Can Start**: after Stream A
**Dependencies**: Stream A

## Coordination Points
### Shared Files
### Sequential Requirements

## Conflict Risk Assessment

## Parallelization Strategy

## Expected Timeline
- With parallel execution: <max_stream_hours>h wall time
- Without: <sum_all_hours>h
- Efficiency gain: <pct>%
```

**Output**: "✅ Analysis complete for issue #<N> — N parallel streams identified. Ready to start? Say: start issue <N>"

---

## Starting an Issue

**Trigger**: User wants to begin work on a specific GitHub issue.

### Preflight
1. Verify issue exists and is open: `gh issue view <N> --json state,title,labels,body`
2. Find local task file (as above).
3. Check for analysis file: `.claude/epics/*/<N>-analysis.md` — if missing, run analysis first (or do both in sequence: analyze then start).
4. Verify epic worktree exists: `git worktree list | grep "epic-<name>"` — if not: "❌ No worktree. Sync the epic first."

### Process

**Step 1 — Read the analysis**, identify which streams can start immediately vs. which have dependencies.

**Step 2 — Create progress tracking:**
```bash
mkdir -p .claude/epics/<epic>/updates/<N>
current_date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
```

Create `.claude/epics/<epic>/updates/<N>/stream-<X>.md` for each stream:
```markdown
---
issue: <N>
stream: <stream_name>
started: <datetime>
status: in_progress
---
## Scope
## Progress
- Starting implementation
```

**Step 3 — Launch parallel agents** for each stream that can start immediately:

```yaml
Task:
  description: "Issue #<N> Stream <X>"
  subagent_type: "general-purpose"
  prompt: |
    You are working on Issue #<N> in the epic worktree at: ../epic-<name>/
    
    Your stream: <stream_name>
    Your scope — files to modify: <file_patterns>
    Work to complete: <stream_description>
    
    Instructions:
    1. Read full task from: .claude/epics/<epic>/<N>.md
    2. Read analysis from: .claude/epics/<epic>/<N>-analysis.md
    3. Check whether this stream's assigned files/scope correspond to entries in the task's Test Plan section (if the mapping isn't exact by file path, use judgment: does this stream implement business logic/services/components the Test Plan lists tests for, versus pure config/docs/infra it doesn't?). If it's application code, follow strict TDD:
       a. RED — write the failing unit test(s) for the next acceptance criterion; run them and confirm they fail for the expected reason.
       b. GREEN — write the minimum implementation to make those tests pass; run them and confirm they pass.
       c. Refactor while keeping tests green; re-run after every change.
       Repeat per acceptance criterion. Never write implementation code before its test exists.
       If this stream's scope is entirely config/docs/infra/generated code with no corresponding Test Plan entries, implement directly — no TDD required.
       If this stream's scope mixes both (some files have Test Plan entries, some don't), apply RED/GREEN/refactor only to the files with entries; implement the rest directly.
    4. Work ONLY in your assigned files
    5. Commit frequently: "Issue #<N>: <specific change>"
    6. Update progress in: .claude/epics/<epic>/updates/<N>/stream-<X>.md
    7. If you need to touch files outside your scope, note it in your progress file and wait
    8. Never use --force on git operations
    
    Complete your stream's work and mark status: completed when done.
```

Streams with unmet dependencies are queued — launch them as their dependencies complete.

**Step 4 — Assign on GitHub:**
```bash
gh issue edit <N> --add-assignee @me --add-label "in-progress"
```

**Step 5 — Create execution status file** at `.claude/epics/<epic>/updates/<N>/execution.md`:
```markdown
## Active Streams
- Stream A: <name> — Started <time>
- Stream B: <name> — Started <time>

## Queued
- Stream C: <name> — Waiting on Stream A

## Completed
(none yet)
```

**Output:**
```
✅ Started work on issue #<N>

Launched N agents:
  Stream A: <name> ✓ Started
  Stream B: <name> ✓ Started
  Stream C: <name> ⏸ Waiting (depends on A)

Monitor: check progress in .claude/epics/<epic>/updates/<N>/
Sync updates: "sync issue <N>"
```

**Step 6 — Mandatory Review (before the issue can close):**

Once every stream for this issue reports `status: completed`:

1. From inside the epic worktree (`cd ../epic-<name>/`), collect only this issue's own commits, in chronological order — never a commit range, since other issues' agents may be committing to this same shared worktree/branch concurrently (see "Starting a Full Epic" and "Agent Coordination Rules" below) and would otherwise leak into a range diff:
```bash
cd ../epic-<name>/
git log --grep="^Issue #<N>:" -p --reverse > /tmp/issue-<N>-diff.patch
if [ ! -s /tmp/issue-<N>-diff.patch ]; then
  echo "❌ No commits matched '^Issue #<N>:' — check the commit message format (see Step 3) before continuing. Do not proceed to review with an empty diff."
fi
```
2. Launch a review subagent on a cheap model:
```yaml
Task:
  description: "Code review — Issue #<N>"
  subagent_type: "general-purpose"
  model: haiku   # cheapest current Claude tier — use whatever the latest Haiku release is at run time; substitute the equivalent low-cost tier if not running on Claude
  prompt: |
    Review the changes for Issue #<N> in ../epic-<name>/.
    Diff to review: /tmp/issue-<N>-diff.patch (this issue's own commits only — do not substitute a commit-range diff, which may include other issues' concurrent work on the same branch)
    Invoke the `code-review` skill against this diff at effort level "medium".
    Report findings using the skill's normal findings format.
```
3. Triage every finding immediately (do not defer to a later task) — the skill's "medium" effort level does not always attach a CONFIRMED/PLAUSIBLE verdict, so triage by substance, not by the presence of that label:
   - Application code (per Step 3's TDD scope): any correctness bug, or any finding that would block a task that lists this issue in its `depends_on`, must be fixed now — write a failing regression test first (RED), fix it (GREEN), re-run tests.
   - Non-application code (config/docs/infra/build-scripts/generated — TDD-exempt per Step 3): fix correctness bugs directly, no preceding test required; still fix immediately if it would block a dependent task.
   - Only pure style/naming/simplification findings with no functional impact may be recorded and deferred without blocking.
4. Record the outcome at `.claude/epics/<epic>/updates/<N>/review.md`:
```markdown
---
issue: <N>
reviewed: <run: date -u +"%Y-%m-%dT%H:%M:%SZ">
model: <model actually used for the review, e.g. haiku>
verdict: passed | changes_requested
---
## Findings Addressed
## Findings Deferred (non-blocking)
```
5. Only proceed to "Closing an Issue" (sync.md) once verdict is `passed`.

---

## Starting a Full Epic

**Trigger**: User wants to launch parallel agents across all ready issues in an epic at once.

### Preflight
- Verify `.claude/epics/<name>/epic.md` exists and has a `github:` field (i.e., it's been synced).
- Check for uncommitted changes: `git status --porcelain` — block if dirty.
- Verify epic branch exists: `git branch -a | grep "epic/<name>"`

### Process

**Step 1 — Read all task files** in `.claude/epics/<name>/`. Parse frontmatter for `status`, `depends_on`, `parallel`.

**Step 2 — Categorize tasks:**
- Ready: status=open, no unmet depends_on
- Blocked: has unmet depends_on
- In Progress: already has an execution file
- Complete: status=closed

A `depends_on` entry is only "met" once the prerequisite task's `status` is `closed` — not merely `completed`. `status: closed` requires sync.md's "Closing an Issue" Preflight, which requires `review.md` verdict: passed (the "Mandatory Review" step under "Starting an Issue" above). This is deliberate: a dependent stream should never build on a prerequisite's implementation before it has passed mandatory review, since review may still change that implementation.

**Step 3 — Analyze any ready tasks** that don't have an analysis file yet (run issue analysis inline).

**Step 4 — Launch agents** for all ready tasks following the same per-issue agent launch pattern above.

**Step 5 — Create/update** `.claude/epics/<name>/execution-status.md` with all active agents and queued issues.

**Step 6 — As issues close** (i.e., after the "Mandatory Review" step passes and sync.md closes them — not merely when a stream self-reports `status: completed`), check if blocked issues are now unblocked and launch those agents.

---

## Agent Coordination Rules

When multiple agents work in the same worktree simultaneously:

- Each agent works only on files in its assigned stream scope.
- Agents commit frequently with `Issue #<N>: <description>` format.
- Before modifying a shared file, check `git status <file>` — if another agent has it modified, wait and pull first.
- Agents sync via commits: `git pull --rebase origin epic/<name>` before starting new file work.
- Conflicts are never auto-resolved — agents report them and pause.
- No `--force` flags ever.

Shared files that commonly need coordination (types, config, package.json) should be handled by one designated stream; others pull after that commit.
