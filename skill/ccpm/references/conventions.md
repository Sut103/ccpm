# Conventions — File Formats, Paths & Rules

Read this before doing any file operations across all phases.

---

## Language & Content Style

All content this skill authors — PRDs, epics, tasks, bug reports, and anything posted to GitHub (issue titles, issue bodies, pull request titles/bodies) — must be written in Japanese (日本語). This includes prose section headers (e.g. `## 概要` rather than `## Overview`), so that issues read naturally on GitHub, not just the paragraph content under them.

This is the single source of truth for the rule — plan.md, structure.md, and sync.md's templates just point back here rather than restating it, so update it in one place.

Exceptions — keep these in English/ASCII, since scripts and this skill's own instructions parse them literally:
- YAML frontmatter *structural* keys and enum-like values: `status`, `parallel`, `depends_on`, `conflicts_with`, `github`, `created`/`updated` dates, `progress`, `bug_for` (e.g. `status: open`, `parallel: true`, `depends_on: []`)
- The PRD's and Epic's `name:` frontmatter field — this *is* the kebab-case feature-name slug (`user-auth`), reused verbatim to build file paths (`.claude/epics/<name>/`, `../epic-<name>/`) and must stay ASCII. The Task's and Bug's `name:` field is different: it's a human-readable title with no slug role, used verbatim as the GitHub issue title (`gh issue create --title "<task_name>"` in sync.md) — write it in Japanese. The PRD's `description:` (a one-line prose summary, not a slug) is likewise Japanese.
  Always wrap these Japanese `name:`/`description:` values in double quotes (`name: "バグ: ログイン失敗"`), even when today's text happens not to contain a colon — a natural Japanese title often reads better with one (e.g. `見出し: 詳細`), and an unquoted colon-plus-space inside a YAML value breaks frontmatter parsing.
- Section header labels this skill's own instructions reference by exact text — e.g. execute.md's "Starting an Issue" → Step 3 per-stream agent prompt reads "the task's テスト計画（先に書く — TDD）section" precisely because structure.md's header was renamed to that exact text; when renaming a template header, grep the other reference files for its old name and update every cross-reference to match verbatim (`validate.sh` and friends only parse frontmatter, not prose headers, so this only affects other `.md` instruction files)

This skill has no pull-request-creation step today — `gh pr create` appears nowhere in these reference docs, and "Merging an Epic" (sync.md) merges the epic branch directly with `git merge` rather than opening a PR. If a future step in this workflow ever opens a pull request, its title and body must follow the same Japanese rule above, and the body specifically must stay concise: lead with the key point (what changed and why), skip anything redundant with the diff or the linked issue, and prefer a short bulleted summary over long prose.

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
sed '1,/^---$/d; 1,/^---$/d' <file> > /tmp/body.md
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
| `gh extension list/install` (gh-sub-issue) | not available via MCP — fall back to a plain `#N` reference in the issue body (see sync.md's "親エピック: #N" pattern) |

### Getting Issue Numbers
```bash
# From a task file's github field:
grep 'github:' <file> | grep -oE '[0-9]+$'
```

---

## Git / Worktree Conventions

- One branch per epic: `epic/<name>`
- Worktrees live at `../epic-<name>/` (sibling to project root)
- Always start branches from an up-to-date main:
  ```bash
  git checkout main && git pull origin main
  git worktree add ../epic-<name> -b epic/<name>
  ```
- Commit format inside epics: `Issue #<N>: <description>`
- Never use `--force` in any git operation

---

## Naming Conventions

- Feature names: kebab-case, lowercase, letters/numbers/hyphens, starts with a letter
- Task files before sync: `001.md`, `002.md`, ... (sequential)
- Task files after sync: renamed to GitHub issue number (e.g., `1234.md`)
- Labels applied on sync: `epic`, `epic:<name>`, `feature` (for epics); `task`, `epic:<name>` (for tasks)

---

## Epic Progress Calculation

```bash
total=$(ls .claude/epics/<name>/[0-9]*.md 2>/dev/null | wc -l)
closed=$(grep -l '^status: closed' .claude/epics/<name>/[0-9]*.md 2>/dev/null | wc -l)
progress=$((closed * 100 / total))
```

Update epic frontmatter when any task closes.
