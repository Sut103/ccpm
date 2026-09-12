# Conventions — File Formats, Paths & Rules

Read this before doing any file operations across all phases.

---

## Language & Content Style

Template structure — section headings (`## Overview`, `## Acceptance Criteria`, etc.), fixed checklist wording (Definition of Done, Effort Estimate labels), canned comment templates (progress-update headers, completion/close messages), and `<placeholder>` markers — stays in English. This is this skill's own fixed vocabulary, shared across plan.md/structure.md/sync.md/execute.md, and translating it earlier caused templates to drift out of sync with the cross-references that name them (e.g. execute.md's per-stream agent prompt reading "the task's Test Plan section", referring to structure.md's `## Test Plan (write first — TDD)` heading).

Written in Japanese instead — except each template's own fixed "PRD:"/"Epic:"/"Task:"/"Bug:" label (used in that file's own H1 heading, and for Epic/Bug also in the GitHub issue `--title`), which is template vocabulary like any other heading and stays English; only the content after that fixed label is Japanese. A Task issue's actual GitHub title and `name:` frontmatter value carry no such label at all (just `<task_name>` — sync.md's `--title "<task_name>"` has no "Task:" prefix), even though the task file's own local H1 heading does say "# Task: ...", the same as every other template's H1:
- GitHub issue titles (`gh issue create --title ...`) and, for the Task/Bug templates, the `name:` frontmatter field that becomes that title verbatim.
- The PRD's `description:` field (a one-line prose summary).
- The actual free-form content a PRD/epic/task/bug report is filled in with — the paragraphs, acceptance-criteria bullets, and test-plan entries the agent authors under each (English) heading. That's what a Japanese-speaking user actually reads; the heading above it is just a label.

This is the single source of truth for the rule — plan.md, structure.md, and sync.md's templates just point back here rather than restating it, so update it in one place.

If a template heading is ever renamed, grep the other reference files for its old exact text and update every cross-reference to match verbatim — e.g. execute.md's "Starting an Issue" → per-stream agent prompt names "the task's Test Plan section" by that exact heading text from structure.md (avoid citing it by step number, since inserting/removing a step elsewhere in that same flow renumbers it); a rename that isn't propagated leaves the two out of sync (`validate.sh` and friends only parse frontmatter, not prose headers, so this only affects other `.md` instruction files).

Exceptions — keep these in English/ASCII, since scripts and this skill's own instructions parse them literally:
- YAML frontmatter *structural* keys and enum-like values: `status`, `parallel`, `depends_on`, `conflicts_with`, `github`, `created`/`updated` dates, `progress`, `bug_for` (e.g. `status: open`, `parallel: true`, `depends_on: []`)
- The PRD's and Epic's `name:` frontmatter field — this *is* the kebab-case feature-name slug (`user-auth`), reused verbatim to build file paths (`.claude/epics/<name>/`, `../epic-<name>-<N>/` per-task worktrees) and must stay ASCII.
- The Task's and Bug's `name:` field is different: it's the human-readable title used verbatim as the GitHub issue title (per the Japanese/label split above) — always wrap it in double quotes (`name: "Bug: ログイン失敗"`), since the Bug template's embedded "Bug:" colon would otherwise break YAML frontmatter parsing. The Task template has no fixed label to worry about, but quote it too whenever the Japanese title happens to contain its own colon.

### Pull Requests

Every task gets its own PR (see Git / Worktree Conventions below for the stacking rule) — never one PR for the whole epic. A PR's title is the task's `<task_name>` (Japanese, same as its issue title — no fixed label, per above). Its body:
- Opens with `Closes #<N>` (the task's own issue number, in English — this is a real PR, so GitHub's auto-close keyword works here, unlike the issue-to-issue `Part of #N`/`Related to #N` references elsewhere in this skill, which never trigger auto-close).
- Otherwise follows the Japanese rule above (headings stay English, content is Japanese) and must stay concise: lead with the key point (what changed and why), skip anything redundant with the diff or the linked issue, and prefer a short bulleted summary over long prose.

---

## Directory Structure

```
.claude/
├── prds/
│   └── <feature-name>.md          # Product requirement documents
├── epics/
│   ├── <feature-name>/
│   │   ├── epic.md                # Technical epic
│   │   ├── <N>.md                 # Task files (named by GitHub issue number after sync)
│   │   ├── <N>-analysis.md        # Parallel work stream analysis
│   │   ├── github-mapping.md      # Issue number → URL mapping
│   │   ├── execution-status.md    # Active agents tracker
│   │   └── updates/
│   │       └── <issue_N>/
│   │           ├── stream-A.md    # Per-agent progress
│   │           ├── progress.md    # Overall issue progress
│   │           ├── pr.md          # This task's branch/base/PR — set once at worktree creation, read back later
│   │           ├── review.md      # Mandatory code-review verdict before closing
│   │           └── execution.md  # Execution state
│   └── archived/
│       └── <feature-name>/        # Completed epics
└── context/                       # Project context docs (separate system)
```

---

## Frontmatter Schemas

### PRD (.claude/prds/<name>.md)
```yaml
---
name: <feature-name>          # kebab-case, matches filename — ASCII, not Japanese (see § Language & Content Style)
description: "<one-liner>"    # Japanese prose, quoted — used in lists and summaries
status: backlog | active | completed
created: <ISO 8601>         # date -u +"%Y-%m-%dT%H:%M:%SZ"
---
```

### Epic (.claude/epics/<name>/epic.md)
```yaml
---
name: <feature-name>
status: backlog | in-progress | completed
created: <ISO 8601>
updated: <ISO 8601>
progress: 0%                # recalculated when tasks close
prd: .claude/prds/<name>.md
github: https://github.com/<owner>/<repo>/issues/<N>  # set on sync
---
```

### Task (.claude/epics/<name>/<N>.md)
```yaml
---
name: "<Task Title>"          # Japanese, quoted — used verbatim as the GitHub issue title
status: open | in-progress | closed
created: <ISO 8601>
updated: <ISO 8601>
github: https://github.com/<owner>/<repo>/issues/<N>  # set on sync
depends_on: []              # issue numbers this must wait for
parallel: true              # can run concurrently with non-conflicting tasks
conflicts_with: []          # issue numbers that touch the same files
---
```

### Progress (.claude/epics/<name>/updates/<N>/progress.md)
```yaml
---
issue: <N>
started: <ISO 8601>
last_sync: <ISO 8601>
completion: 0%
---
```

### PR (.claude/epics/<name>/updates/<N>/pr.md)
```yaml
---
issue: <N>
branch: epic/<name>/<N>
base: main | epic/<name>/<dep_N>   # written once, at worktree creation (execute.md § Starting an Issue, Step 2) — the PR must target this exact base, not whatever depends_on shows later, since that can change after the branch is cut
pr_number:                          # empty until the PR is created (Step 7); read back in Step 8 and by sync.md § Merging a Task PR
---
```

### Review (.claude/epics/<name>/updates/<N>/review.md)
```yaml
---
issue: <N>
reviewed: <ISO 8601>
model: <model actually used for the review, e.g. haiku>
verdict: passed | changes_requested
---
```

---

## Datetime Rule

Always get real current datetime from the system — never use placeholder text:
```bash
date -u +"%Y-%m-%dT%H:%M:%SZ"
```

---

## Frontmatter Update Pattern

When updating a single frontmatter field in an existing file:
```bash
sed -i.bak "/^<field>:/c\\<field>: <value>" <file>
rm <file>.bak
```

When stripping frontmatter to get body content for GitHub:
```bash
sed '1,/^---$/d' <file> > /tmp/body.md
```

---

## GitHub Operations

### Repository Safety Check (run before any write operation)
```bash
remote_url=$(git remote get-url origin 2>/dev/null || echo "")
if [[ "$remote_url" == *"automazeio/ccpm"* ]]; then
  echo "❌ Cannot write to the CCPM template repository."
  echo "Update remote: git remote set-url origin https://github.com/YOUR/REPO.git"
  exit 1
fi
REPO=$(echo "$remote_url" | sed 's|.*github.com[:/]||' | sed 's|\.git$||')
```

### Authentication & MCP Fallback
Don't pre-check authentication for `gh` itself — run the command and handle failure. But do check whether `gh` is installed at all, since some environments only offer the GitHub MCP server:

```bash
if command -v gh >/dev/null 2>&1; then
  gh <command> || echo "❌ GitHub CLI failed. Run: gh auth login"
else
  echo "ℹ️ gh CLI not found — falling back to MCP GitHub tools."
  # Use the equivalent mcp__github__* tool instead (see table below).
fi
```

If `gh` is not installed/available in this environment, use the GitHub MCP server tools (commonly prefixed `mcp__github__*`) as a drop-in replacement. Exact tool names vary by MCP server configuration — check the available tool list — but the common mapping is:

| gh command | MCP tool equivalent |
|---|---|
| `gh issue create` | `mcp__github__issue_write` (method: create) |
| `gh issue view <N> --json ...` | `mcp__github__issue_read` |
| `gh issue edit <N> --add-assignee/--add-label` | `mcp__github__issue_write` (method: update) |
| `gh issue comment <N>` | `mcp__github__add_issue_comment` |
| `gh issue close <N>` | `mcp__github__issue_write` (method: update, state: closed) |
| `gh label create/list` | no direct equivalent — skip label automation and note it for manual follow-up |
| `gh extension list/install` (gh-sub-issue) | not available via MCP — fall back to a plain `#N` reference in the issue body (see sync.md's "Part of #N" pattern) |
| `gh pr create` | `mcp__github__create_pull_request` |
| `gh pr merge` | `mcp__github__merge_pull_request` |
| `gh pr view <N> --json ...` | `mcp__github__pull_request_read` |

### Getting Issue Numbers
```bash
# From a task file's github field:
grep 'github:' <file> | grep -oE '[0-9]+$'
```

---

## Git / Worktree Conventions

PRs are per-task, not per-epic — a task's PR stacks on its dependency's branch when that dependency has started but not yet merged (GitHub Stacked PRs), so review stays small and independent instead of one giant epic-sized PR at the end. A task only ever stacks on a dependency that *already has a branch* — never on one that hasn't started yet — so there's no launch-ordering to coordinate between parallel agents (execute.md § Starting a Full Epic launches every Ready task independently). See execute.md § Starting an Issue for the full flow.

- One branch per **task**: `epic/<name>/<N>` (`<N>` is the GitHub issue number — a task branch is only ever created after sync, once the issue exists)
- Worktrees live at `../epic-<name>-<N>/` (sibling to project root) — one per task, not one shared worktree for the whole epic. Multiple streams within the *same* task still share that task's single worktree/branch (see Agent Coordination Rules below).
- **Base branch selection**, decided once per task, right before creating its worktree:
  - No `depends_on`, or every entry already `status: closed` (merged) → base = `main` (fetched fresh, not checked out — see below).
  - Exactly one `depends_on` entry not yet closed, and that dependency has already started (has its own worktree/branch — `updates/<dep_N>/execution.md` exists) → base = that dependency's branch, `epic/<name>/<dep_N>`. This is the actual stack.
  - Anything else (two or more unmet entries, or the one unmet entry hasn't started yet) → not actually Ready per execute.md § Starting a Full Epic; this case doesn't reach worktree creation at all.
  Never `git checkout`/`git pull` the shared main repo to resolve `main` — several independent Ready tasks can be launched at once, and a shared checkout would race between them. `git fetch origin main` and start the worktree from `origin/main` instead; see execute.md § Starting an Issue, Step 2 for the exact commands.
  Record `base` in `.claude/epics/<name>/updates/<N>/pr.md` (see Frontmatter Schemas) right after creating the worktree — it's needed again when opening the PR, and by then `depends_on`'s live status may have changed, so the PR must target the base actually used here, not a freshly recomputed one.
- Commit format inside a task's worktree: `Issue #<N>: <description>`
- Never use `--force` in any git operation
- A stacked task's dependency can still merge (and its branch get deleted) while the stacked task is mid-flight — that's a normal, expected event for a stack, not a race to prevent. Handle it when opening the PR (execute.md § Starting an Issue, Step 7): if the dependency has merged, rebase onto `main` and open against `main` instead.

---

## Naming Conventions

- Feature names: kebab-case, lowercase, letters/numbers/hyphens, starts with a letter
- Task files before sync: `001.md`, `002.md`, ... (sequential)
- Task files after sync: renamed to GitHub issue number (e.g., `1234.md`)
- Task branches: `epic/<name>/<N>` where `<N>` is the GitHub issue number (e.g., `epic/user-auth/1234`) — "Starting an Issue" requires the issue to already exist (its Preflight runs `gh issue view <N>`), so a task branch is never created before the task is synced and never uses the pre-sync sequential filename
- Labels applied on sync: `epic`, `epic:<name>`, `feature` (for epics); `task`, `epic:<name>` (for tasks)

---

## Epic Progress Calculation

```bash
total=$(ls .claude/epics/<name>/[0-9]*.md 2>/dev/null | wc -l)
closed=$(grep -l '^status: closed' .claude/epics/<name>/[0-9]*.md 2>/dev/null | wc -l)
progress=$((closed * 100 / total))
```

Update epic frontmatter when any task closes.
