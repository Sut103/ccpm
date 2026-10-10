# Execute — Start Building with Parallel Agents

This phase covers analyzing GitHub issues for parallel work streams and launching agents to execute them.

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
- Which test cases (`TC-<n>`) from the task file does each stream's behavior cover?

**Common stream patterns:**
- Database Layer: schema, migrations, models
- Service Layer: business logic, data access
- API Layer: endpoints, validation, middleware
- UI Layer: components, pages, styles

There is no separate test stream: each stream owns the test cases for the behavior it builds and writes them first (see `conventions.md` → TDD & Test Traceability). Assign every `TC-<n>` in the task file to exactly one stream:
- A test case that needs the work of several streams goes to the stream that finishes last in the dependency chain; assigning it to an earlier stream deadlocks, because that stream cannot pass the test until later streams are done.
- Every stream that adds behavior owns at least one test case. If an earlier stream is left with none, add unit-level test cases for its part to the task's `## Test Cases` (a task-only change, see `conventions.md` → Changing Test Cases), or merge it into the stream that owns the test case. A stream that adds no observable behavior writes `N/A — <reason>` instead (see Exceptions).
- Test cases that share a test file go to the same stream; otherwise split the file. List each stream's test files in its **Files**.
- Shared test fixtures and helpers follow the shared-file rule below: one designated stream owns them.

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
**Test Cases**: TC-1, TC-2
**Can Start**: immediately
**Estimated Hours**: 
**Dependencies**: none

### Stream B: <Name>
**Scope**: 
**Files**: 
**Test Cases**: TC-3
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
5. Stack delivery only: the task directly below this one (by `position`) is `in-review` or `closed`, or this is the bottom layer. Otherwise: "❌ #<N> waits for layer #<below_N> to be submitted." Then put the worktree on this layer's branch:
   ```bash
   cd ../epic-<name>
   git checkout epic/<name>/<N> 2>/dev/null || git checkout -b epic/<name>/<N> epic/<name>/<below_N>
   ```
   The bottom layer's branch already exists from the epic sync.

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
    Stack delivery only — your branch: epic/<name>/<N>. Never switch branches.
    
    Your stream: <stream_name>
    Your scope — files to modify: <file_patterns>
    Your test cases: <TC IDs>
    Work to complete: <stream_description>
    
    Instructions:
    1. Read full task from: .claude/epics/<epic>/<N>.md
    2. Read analysis from: .claude/epics/<epic>/<N>-analysis.md
    3. Read TDD rules from: <skill_path>/references/conventions.md → TDD & Test Traceability
    4. Work ONLY in your assigned files
    5. Work test-first, following those rules:
       a. Red: write tests for your test cases, tagged "[#<N> TC-<n>]", run them, and
          confirm they fail for the expected reason (commit a minimal stub with them if the
          test cannot compile). Commit: "Issue #<N>: add failing tests for <TC IDs>"
       b. Green: write the minimal code that makes them pass.
          Commit: "Issue #<N>: <specific change>"
       c. Refactor: clean up while keeping all tests green. Commit if anything changed.
       If your stream's Test Cases are "N/A — <reason>", skip the test steps (Red, Green,
       Refactor): do the work described, then go to step 6.
    6. Run the project's full test suite (<test command from the epic's Test Strategy>).
       If your change broke a previously passing test, fix your change. Failing tests of
       another active stream or another open task are expected; leave them alone. If the
       suite cannot build because of someone else's change, wait and pull; don't fix it.
    7. Update progress in: .claude/epics/<epic>/updates/<N>/stream-<X>.md
    8. If you need to touch files outside your scope, note it in your progress file and wait
    9. Never use --force on git operations
    
    Mark status: completed only when all your test cases pass and no previously passing test fails.
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

With stack delivery, submit the task once every stream has completed (`sync.md` → Submitting a Task).

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

**Step 3 — Analyze any ready tasks** that don't have an analysis file yet (run issue analysis inline).

**Step 4 — Launch agents** for all ready tasks following the same per-issue agent launch pattern above. With stack delivery, only one task is ready at a time: the lowest layer that is still `open`.

**Step 5 — Create/update** `.claude/epics/<name>/execution-status.md` with all active agents and queued issues.

**Step 6 — As agents complete**, check if blocked issues are now unblocked and launch those agents. With stack delivery, submit the finished task first; its submission unblocks the next layer.

---

## Agent Coordination Rules

When multiple agents work in the same worktree simultaneously:

- Each agent works only on files in its assigned stream scope.
- Agents commit frequently with `Issue #<N>: <description>` format.
- Before modifying a shared file, check `git status <file>` — if another agent has it modified, wait and pull first.
- Agents sync via commits: `git pull --rebase origin epic/<name>` before starting new file work. With stack delivery the layer branch exists only locally until it is submitted, so skip the pull.
- Conflicts are never auto-resolved — agents report them and pause.
- A stream is not complete until its own test cases pass and no previously passing test fails. Red tests from another active stream or open task are expected while that work is in progress; leave them alone. Never weaken or delete a test to make it pass.
- No `--force` flags ever.

Shared files that commonly need coordination (types, config, package.json) should be handled by one designated stream; others pull after that commit.
