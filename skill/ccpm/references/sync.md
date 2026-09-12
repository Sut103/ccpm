# Sync — Push to GitHub & Track Progress

This phase covers pushing local epics/tasks to GitHub as issues, syncing progress as comments, and closing issues when work is done.

All `gh` commands in this phase follow the availability/fallback rule in conventions.md § Authentication & MCP Fallback.

---

## Repository Safety Check

**Always run this before any GitHub write operation:**

```bash
remote_url=$(git remote get-url origin 2>/dev/null || echo "")
if [[ "$remote_url" == *"automazeio/ccpm"* ]]; then
  echo "❌ Cannot sync to the CCPM template repository."
  echo "Update remote: git remote set-url origin https://github.com/YOUR/REPO.git"
  exit 1
fi
REPO=$(echo "$remote_url" | sed 's|.*github.com[:/]||' | sed 's|\.git$||')
```

---

## Epic Sync — Push Epic + Tasks to GitHub

**Trigger**: User wants to push a local epic and its tasks to GitHub as issues.

### Preflight
- Verify `.claude/epics/<name>/epic.md` exists.
- Verify numbered task files exist — if none: "❌ No tasks to sync. Decompose the epic first."

### Process

**Step 1 — Create epic issue:**

Strip frontmatter from epic.md, then:
```bash
sed '1,/^---$/d' .claude/epics/<name>/epic.md > /tmp/epic-body.md
epic_number=$(gh issue create \
  --repo "$REPO" \
  --title "Epic: <name>" \
  --body-file /tmp/epic-body.md \
  --label "epic,epic:<name>,feature" \
  --json number -q .number)
```

**Step 2 — Create task sub-issues:**

Check if `gh-sub-issue` extension is available:
```bash
if command -v gh &> /dev/null && gh extension list | grep -q "yahsan2/gh-sub-issue"; then
  use_subissues=true
else
  use_subissues=false
  # gh not installed, or the extension isn't present — per conventions.md's fallback
  # table, fall back to a plain "#<parent_number>" reference in the issue body.
fi
```

For <5 tasks: create sequentially.
For ≥5 tasks: use parallel Task agents (3-4 tasks per batch). Each agent runs in its own shell context, so include the resolved `use_subissues` (true/false) and `epic_number` values directly in that agent's prompt — do not assume the variables set above are visible to it.

Per task (namespace temp files by the task's current filename number — parallel batches write these concurrently, and a shared path would race):
```bash
sed '1,/^---$/d' <task_file> > /tmp/task-body-<task_num>.md
if [ "$use_subissues" = false ]; then
  # No gh-sub-issue extension available — link back to the parent epic issue directly in the body.
  { echo "Part of #$epic_number"; echo; cat /tmp/task-body-<task_num>.md; } > /tmp/task-body-<task_num>.md.tmp
  mv /tmp/task-body-<task_num>.md.tmp /tmp/task-body-<task_num>.md
fi
task_number=$(gh issue create \
  --repo "$REPO" \
  --title "<task_name>" \
  --body-file /tmp/task-body-<task_num>.md \
  --label "task,epic:<name>" \
  --json number -q .number)
# or with sub-issues (when $use_subissues is true):
# gh sub-issue create --parent $epic_number ...
```

**Step 3 — Rename task files and update references:**

After all issues are created, rename `001.md` → `<issue_number>.md` and update all `depends_on`/`conflicts_with` arrays to use real issue numbers (not sequential numbers).

```bash
# Build old→new mapping, then for each task file:
sed -i.bak "s/\b001\b/<new_num_1>/g" <file>  # repeat for each mapping
mv 001.md <new_num>.md
```

**Step 4 — Update frontmatter:**
```bash
current_date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
# Update github: and updated: fields in epic.md and each task file
github_url="https://github.com/$REPO/issues/<number>"
sed -i.bak "/^github:/c\\github: $github_url" <file>
sed -i.bak "/^updated:/c\\updated: $current_date" <file>
rm <file>.bak
```

**Step 5 — Create github-mapping.md:**
```markdown
# GitHub Issue Mapping
Epic: #<N> - https://github.com/<repo>/issues/<N>
Tasks:
- #<N>: <title> - https://github.com/<repo>/issues/<N>
Synced: <datetime>
```

No worktree or branch is created here — each task gets its own worktree/branch (and Stacked PR) only when work on it actually starts, per execute.md § Starting an Issue.

**Output:**
```
✅ Synced epic <name> to GitHub
  Epic: #<N>
  Tasks: N sub-issues
  Next: "start working on issue <N>" or "start the <name> epic"
```

---

## Issue Sync — Post Progress to GitHub

**Trigger**: User wants to sync local development progress to a GitHub issue as a comment.

### Preflight
- Verify issue exists: `gh issue view <N> --json state`
- Check `.claude/epics/*/updates/<N>/` exists with a `progress.md` file.
- Check `last_sync` in progress.md — if synced <5 minutes ago, confirm before proceeding.

### Process

Gather updates from `.claude/epics/<epic>/updates/<N>/` (progress.md, notes.md, commits.md).

Format and post a comment:
```bash
gh issue comment <N> --body-file /tmp/update-comment.md
```

Comment format (headings stay in English per conventions.md § Language & Content Style; write the content under each heading in Japanese):
```markdown
## 🔄 Progress Update - <date>

### ✅ Completed Work
### 🔄 In Progress
### 📝 Technical Notes
### 📊 Acceptance Criteria Status
### 🚀 Next Steps
### ⚠️ Blockers

---
*Progress: N% | Synced at <timestamp>*
```

After posting: update `last_sync` in progress.md frontmatter, update `updated` in the task file.

Add sync marker to local files to prevent duplicate comments:
```markdown
<!-- SYNCED: <datetime> -->
```

---

## Merging a Task PR

**Trigger**: This task's Mandatory Review (execute.md § Starting an Issue, Step 8) reports `verdict: passed`, or the user explicitly asks to merge/close a task's PR.

This is the actual completion mechanism now that PRs are per-task and stacked (see conventions.md § Git / Worktree Conventions) — there's no separate epic-wide merge step. Merging bottom-up through a stack is what lands every task on `main`.

### Preflight
- Verify `.claude/epics/*/updates/<N>/review.md` exists with `verdict: passed`. If missing or `verdict: changes_requested`, stop and run the review step in execute.md § Mandatory Review first.
- Check for uncommitted changes in the task's worktree (`../epic-<name>-<N>/`) — block if dirty; `git worktree remove` below refuses to remove a dirty worktree, so a stream that left uncommitted work must commit or discard it first.
- Run project tests if detectable in the task's worktree — `npm test` / `pytest` / `cargo test` / `go test` / etc.
- If this task's PR is stacked on another task's still-open PR, its base hasn't merged yet — merge dependencies first (the stack merges bottom-up).

### Process

```bash
pr_number=$(grep '^pr_number:' .claude/epics/<epic>/updates/<N>/pr.md | sed 's/^pr_number: *//')
gh pr merge "$pr_number" --squash    # or --merge/--rebase per project convention; auto-closes issue #<N> via "Closes #<N>" in the PR body

# Cleanup this task's worktree/branch — from the main repo checkout, not from
# inside the worktree itself (git refuses to remove your current directory)
cd <main repo root>
git worktree remove ../epic-<name>-<N>
git branch -D epic/<name>/<N>   # -D, not -d: after a squash merge the branch's
                                  # own commits are never ancestors of the target,
                                  # so the safe delete would refuse
git push origin --delete epic/<name>/<N>
```

If another task's branch was stacked on this one, GitHub retargets its open PR to this PR's base automatically once `epic/<name>/<N>` is deleted; that task's agent should still `git pull --rebase origin <new_base>` in its own worktree to pick up the merged changes before continuing.

**Post-merge bookkeeping** (the issue itself is already closed by GitHub via `Closes #<N>`), done from the main repo checkout on an up-to-date `main` (`git pull origin main` first):
1. Update the local task file's frontmatter: `status: closed`, `updated: <now>`.
2. Check off the task in the epic issue body:
```bash
gh issue view <epic_N> --json body -q .body > /tmp/epic-body.md
sed -i "s/- \[ \] #<N>/- [x] #<N>/" /tmp/epic-body.md
gh issue edit <epic_N> --body-file /tmp/epic-body.md
```
3. Recalculate and update epic progress: `progress = closed_tasks / total_tasks * 100`
4. Commit and push these `.claude/` updates to `main` — other tasks' `next.sh`/`blocked.sh` reads and any future stacking decisions depend on this task's `status: closed` being visible outside this checkout.

---

## Epic Completion

**Trigger**: Every task issue in the epic is `status: closed` (i.e., every Stacked PR has merged) — check with `references/scripts/epic-status.sh <name>`, or the user asks to wrap up the epic.

There's no epic-wide merge here — each task's PR already merged individually via "Merging a Task PR" above. This step just closes out bookkeeping once nothing is left open.

### Preflight
- Verify no task issue in the epic has `status` other than `closed`. If any are still open, stop and finish those first (see "Merging a Task PR") — do not offer a "close anyway".
- Verify no leftover worktrees remain: `git worktree list | grep "epic-<name>-"` — remove any (each should already have been cleaned up when its PR merged).

### Process

```bash
# Archive
mkdir -p .claude/epics/archived/
mv .claude/epics/<name> .claude/epics/archived/

# Close the epic issue
epic_issue=$(grep 'github:' .claude/epics/archived/<name>/epic.md | grep -oE '[0-9]+$')
gh issue close $epic_issue -c "Epic completed — all tasks merged to main"
```

Update epic.md frontmatter: `status: completed`.

---

## Reporting a Bug Against a Completed Issue

**Trigger**: User finds a bug while testing a completed or in-progress issue — e.g. "found a bug in issue 42", "email validation is broken, came up while testing issue 42".

The workflow should stay automated: create a linked bug task without losing context from the original issue.

### Process

**Step 1 — Read the original issue for context:**
```bash
gh issue view <original_N> --json title,body,labels
```
Also read the local task file if it exists: `.claude/epics/*/<original_N>.md`

**Step 2 — Create a local bug task file:**

```markdown
---
name: "Bug: <short description>"
status: open
created: <run: date -u +"%Y-%m-%dT%H:%M:%SZ">
updated: <same>
github: (will be set on sync)
depends_on: []
parallel: false
conflicts_with: []
bug_for: <original_N>
---

# Bug: <short description>

## Context
Found while working on / testing issue #<original_N>: <original title>

## Description
<what's broken>

## Steps to Reproduce
<steps>

## Expected vs Actual
- Expected: 
- Actual: 

## Acceptance Criteria
- [ ] Bug is fixed
- [ ] Original issue #<original_N> behaviour is unaffected

## Effort Estimate
- Size: XS/S
```

Section headings and checklist wording stay in English (this skill's own vocabulary — see conventions.md § Language & Content Style); write the actual `<short description>`/`<what's broken>`/`<steps>` content in Japanese. Quote the `name:` value (as shown) since a Japanese short description commonly reads better with a colon, which would otherwise break YAML parsing — keep it identical to the issue title in Step 3 below, just quoted.

Save to `.claude/epics/<same_epic_as_original>/bug-<original_N>-<slug>.md`

**Step 3 — Create a linked GitHub issue:**
```bash
gh issue create \
  --repo "$REPO" \
  --title "Bug: <short description>" \
  --body "$(cat /tmp/bug-body.md)" \
  --label "bug,epic:<epic_name>" \
  --json number -q .number
```

The issue body should open with `Related to #<original_N>` so GitHub auto-links them.

**Step 4 — Update the local file** with the GitHub issue number and rename to `<new_N>.md`.

**Output:**
```
✅ Bug issue created: #<new_N> — "Bug: <short description>"
  Linked to: #<original_N>
  Epic: <epic_name>

Start fixing it: "start working on issue <new_N>"
```
