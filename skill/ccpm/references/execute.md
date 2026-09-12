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
4. Check `depends_on`: every entry must have `status: closed`, except at most one may still be open — and that one must already have *started* (its own worktree/branch exists — check `.claude/epics/<epic>/updates/<dep_N>/execution.md`), since that's what this task stacks its branch on. Two or more still-open entries, or a single still-open one that hasn't started yet, means this task isn't ready — stop and say what to wait for, rather than guessing.
5. Check whether this task's worktree already exists: `[ -d ../epic-<name>-<N> ]` (an exact path check — `git worktree list | grep` on a bare number would also match e.g. task 12 while checking task 1). If it exists, skip Step 2 entirely and resume from the existing `pr.md` (read `base`/`pr_number` from it) instead of recreating the worktree or re-initializing `pr.md`.
6. Check for a leftover flat `epic/<name>` branch/ref from the old one-branch-per-epic model this workflow replaced: `git branch --list "epic/<name>"`. If found, it collides with the new `epic/<name>/<N>` ref namespace (git can't have a branch be both a leaf and a directory) — delete it first (`git branch -D epic/<name>`; `git push origin --delete epic/<name>` if it was pushed) once you've confirmed it's not in-use work.

### Process

**Step 1 — Read the analysis**, identify which streams can start immediately vs. which have dependencies.

**Step 2 — Determine this task's base branch and create its worktree** (skip this step entirely if Preflight found an existing worktree — one worktree per task; see conventions.md § Git / Worktree Conventions for the stacking rule). Fetch instead of checking out `main` in the shared repo, since "Starting a Full Epic" may run this step for several independent tasks in parallel and a shared `git checkout`/`git pull` would race between them:
```bash
git fetch origin main
# Check depends_on entries' status in their task files (Preflight already
# confirmed at most one is unmet).
if [ -z "$depends_on" ] || <every depends_on entry has status: closed>; then
  base="main"
  base_ref="origin/main"
else
  base="epic/<name>/<dep_N>"   # the single unmet dependency from Preflight
  base_ref="$base"
fi
git worktree add ../epic-<name>-<N> -b epic/<name>/<N> "$base_ref"
```
Record `base` now — Step 7 (which may run in a different session) reads it back rather than recomputing it, since `depends_on`'s live status can change between now and then:
```bash
mkdir -p .claude/epics/<epic>/updates/<N>
cat > .claude/epics/<epic>/updates/<N>/pr.md << EOF
---
issue: <N>
branch: epic/<name>/<N>
base: $base
pr_number:
---
EOF
```

**Step 3 — Create progress tracking** (the `updates/<N>/` directory already exists from Step 2):
```bash
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

**Step 4 — Launch parallel agents** for each stream that can start immediately:

```yaml
Task:
  description: "Issue #<N> Stream <X>"
  subagent_type: "general-purpose"
  prompt: |
    You are working on Issue #<N> in its own worktree at: ../epic-<name>-<N>/

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

**Step 5 — Assign on GitHub:**
```bash
gh issue edit <N> --add-assignee @me --add-label "in-progress"
```

**Step 6 — Create execution status file** at `.claude/epics/<epic>/updates/<N>/execution.md`:
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

**Step 7 — Push the branch and open this task's PR** once every stream for this issue reports `status: completed`. This is a Stacked PR, not an epic-sized one — its base is whatever this task actually branched from in Step 2, read back from `pr.md` (not recomputed, since dependency status may have changed since). If `pr_number` in `pr.md` is already set (e.g. resuming after an interruption, or after a Step 8 `changes_requested` cycle), skip straight to pushing the fix commit — `git push` alone updates the existing PR — and do not call `gh pr create` again:
```bash
cd ../epic-<name>-<N>/
pr_number=$(grep '^pr_number:' .claude/epics/<epic>/updates/<N>/pr.md | sed 's/^pr_number: *//')
if [ -n "$pr_number" ]; then
  git push
  exit 0   # PR already exists and is now updated; nothing else in this step to do
fi
base=$(grep '^base:' .claude/epics/<epic>/updates/<N>/pr.md | sed 's/^base: *//')
if [ "$base" != "main" ] && [ "$(gh issue view "$(echo "$base" | sed 's|.*/||')" --json state -q .state)" = "CLOSED" ]; then
  # The dependency merged while this task was still in progress (a normal
  # occurrence for a stack, not an error) — its branch is gone, so rebase
  # onto main and open against main instead. Resolve any conflicts that
  # come up; they're expected to be trivial, since this branch already
  # contains equivalent changes to whatever the dependency's PR merged.
  git fetch origin main
  git rebase origin/main
  base="main"
  sed -i.bak "/^base:/c\\base: main" .claude/epics/<epic>/updates/<N>/pr.md
  rm .claude/epics/<epic>/updates/<N>/pr.md.bak
fi
git push -u origin epic/<name>/<N>
# Namespace by issue number — multiple tasks can reach this step around the
# same time under "Starting a Full Epic", and a shared /tmp path would race.
sed '1,/^---$/d' .claude/epics/<epic>/<N>.md > /tmp/pr-body-<N>.md
{ echo "Closes #<N>"; echo; cat /tmp/pr-body-<N>.md; } > /tmp/pr-body-<N>.md.tmp
mv /tmp/pr-body-<N>.md.tmp /tmp/pr-body-<N>.md
pr_number=$(gh pr create --base "$base" --head epic/<name>/<N> --title "<task_name>" --body-file /tmp/pr-body-<N>.md --json number -q .number)
sed -i.bak "/^pr_number:/c\\pr_number: $pr_number" .claude/epics/<epic>/updates/<N>/pr.md
rm .claude/epics/<epic>/updates/<N>/pr.md.bak
```
If `gh pr create` fails because `$base` doesn't exist on the remote yet (the dependency has started but hasn't pushed), push it yourself first — `git push origin "$base"` — then retry; you have it locally since this task branched from it in Step 2.

**Step 8 — Mandatory Review (before the PR can merge):**

1. Launch a review subagent on a cheap model, targeting the PR directly (not a manually-collected diff — the `code-review` skill accepts a PR number and can post inline review comments). Read `pr_number` back from `pr.md` (`grep '^pr_number:' .claude/epics/<epic>/updates/<N>/pr.md`) if it isn't already in scope:
```yaml
Task:
  description: "Code review — Issue #<N>"
  subagent_type: "general-purpose"
  model: haiku   # cheapest current Claude tier — use whatever the latest Haiku release is at run time; substitute the equivalent low-cost tier if not running on Claude
  prompt: |
    Invoke the `code-review` skill against PR #<pr_number> (the PR opened for Issue #<N> in ../epic-<name>-<N>/) at effort level "medium", with --comment so findings post as inline PR review comments.
    Report findings using the skill's normal findings format.
```
2. Triage every finding immediately (do not defer to a later task) — the skill's "medium" effort level does not always attach a CONFIRMED/PLAUSIBLE verdict, so triage by substance, not by the presence of that label:
   - Application code (per Step 4's TDD scope): any correctness bug, or any finding that would block a task that lists this issue in its `depends_on`, must be fixed now — write a failing regression test first (RED), fix it (GREEN), re-run tests, then push the fix to the same branch (updates the open PR).
   - Non-application code (config/docs/infra/build-scripts/generated — TDD-exempt per Step 4): fix correctness bugs directly, no preceding test required; still fix immediately if it would block a dependent task.
   - Only pure style/naming/simplification findings with no functional impact may be recorded and deferred without blocking.
3. Record the outcome at `.claude/epics/<epic>/updates/<N>/review.md`:
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
4. Only proceed to merging this task's PR (sync.md § Merging a Task PR) once verdict is `passed`.

---

## Starting a Full Epic

**Trigger**: User wants to launch parallel agents across all ready issues in an epic at once.

### Preflight
- Verify `.claude/epics/<name>/epic.md` exists and has a `github:` field (i.e., it's been synced).
- Check for uncommitted changes: `git status --porcelain` — block if dirty.

### Process

**Step 1 — Read all task files** in `.claude/epics/<name>/`. Parse frontmatter for `status`, `depends_on`, `parallel`.

**Step 2 — Categorize tasks:**
- Complete: status=closed
- In Progress: already has an execution file (already has a branch)
- Blocked: status=open, with two or more unmet `depends_on` entries (a branch can only stack on one base), *or* exactly one unmet entry whose dependency hasn't itself started yet (no `updates/<dep_N>/execution.md` — no branch to stack on)
- Ready: status=open, and either no unmet `depends_on` entries, or exactly one whose dependency is already In Progress (that dependency's branch becomes this task's stack base per execute.md § Starting an Issue, Step 2 — the dependency doesn't need to be closed yet, just already started)

This only ever stacks a new task on a dependency that already has a branch — never on one launched in the same batch — so there's no ordering to coordinate between agents: every Ready task's Step 2 can run fully independently and in parallel.

A `depends_on` entry only counts as fully "met" once the prerequisite task's PR has actually merged, i.e. its `status` is `closed` — not merely `completed`. `status: closed` follows from merging its Stacked PR (sync.md § Merging a Task PR), which requires `review.md` verdict: passed (the "Mandatory Review" step under "Starting an Issue" above). A task with exactly one entry that isn't yet met is still Ready (it stacks on that one, per above) rather than Blocked, as long as that dependency has already started — but never build on more than one unmerged prerequisite at a time, since review may still change what an unmerged dependency's PR is building.

**Step 3 — Analyze any ready tasks** that don't have an analysis file yet (run issue analysis inline).

**Step 4 — Launch agents** for all ready tasks following the same per-issue agent launch pattern above. Each ready task creates and works in its own worktree/branch (Step 2 of "Starting an Issue") — tasks are never bundled into one shared epic worktree.

**Step 5 — Create/update** `.claude/epics/<name>/execution-status.md` with all active agents and queued issues.

**Step 6 — As tasks start or their PRs merge**, re-check Blocked tasks: one whose single unmet dependency just started (has an execution file now) or just merged becomes Ready and can be launched.

---

## Agent Coordination Rules

Two levels of coordination apply, since worktrees are now per-task rather than per-epic:

**Across tasks** (different issues, different worktrees, possibly stacked branches):
- Each task's agents work only inside that task's own worktree (`../epic-<name>-<N>/`) — never reach into another task's worktree.
- A task stacked on another (per conventions.md's base-branch rule) inherits that dependency's commits by virtue of branching from it; it never needs to touch the dependency's worktree directly.
- No `--force` flags ever, on any branch.

**Within a task** (multiple streams sharing one worktree/branch simultaneously):
- Each agent works only on files in its assigned stream scope.
- Agents commit frequently with `Issue #<N>: <description>` format.
- Before modifying a shared file, check `git status <file>` — if another agent has it modified, wait and pull first.
- Agents sync via commits: `git pull --rebase origin epic/<name>/<N>` before starting new file work.
- Conflicts are never auto-resolved — agents report them and pause.

Shared files that commonly need coordination (types, config, package.json) should be handled by one designated stream; others pull after that commit.
