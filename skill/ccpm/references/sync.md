# Sync — Push to GitHub & Track Progress

This phase covers pushing local epics/tasks to GitHub as issues, syncing progress as comments, and closing issues when work is done.

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
awk 'NR==1 && /^---$/ {fm=1; next} fm && /^---$/ {fm=0; next} !fm' .claude/epics/<name>/epic.md > /tmp/epic-body.md
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
if gh extension list | grep -q "yahsan2/gh-sub-issue"; then
  use_subissues=true
fi
```

For <5 tasks: create sequentially.
For ≥5 tasks: use parallel Task agents (3-4 tasks per batch).

Per task:
```bash
awk 'NR==1 && /^---$/ {fm=1; next} fm && /^---$/ {fm=0; next} !fm' <task_file> > /tmp/task-body.md
task_number=$(gh issue create \
  --repo "$REPO" \
  --title "<task_name>" \
  --body-file /tmp/task-body.md \
  --label "task,epic:<name>" \
  --json number -q .number)
# or with sub-issues:
# gh sub-issue create --parent $epic_number ...
```

**Step 3 — Rename task files and update references:**

After all issues are created, rename `001.md` → `<issue_number>.md` and update all `depends_on`/`conflicts_with` arrays to use real issue numbers (not sequential numbers).

```bash
# Build old→new mapping, then for each task file:
# only depends_on/conflicts_with lines in frontmatter are rewritten
sed -i.bak -E "/^(depends_on|conflicts_with):/ s/(^|[^0-9])001([^0-9]|$)/\1<new_num_1>\2/g" <file> && rm <file>.bak  # repeat for each mapping
mv 001.md <new_num>.md
```

**Step 4 — Update frontmatter:**
```bash
current_date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
# Update github: and updated: fields in epic.md and each task file
github_url="https://github.com/$REPO/issues/<number>"
# only lines inside the frontmatter are touched (see conventions.md)
set_fm() {
  awk -v k="$1" -v v="$2" '
    NR==1 && /^---$/ {fm=1; print; next}
    fm && /^---$/    {fm=0}
    fm && index($0, k":")==1 {print k": "v; next}
    {print}' "$3" > "$3.tmp" && mv "$3.tmp" "$3"
}
set_fm github "$github_url" <file>
set_fm updated "$current_date" <file>
```

**Step 5 — Create worktree for the epic:**
```bash
git checkout main && git pull origin main
git worktree add ../epic-<name> -b epic/<name>
```

With stack delivery, there is no `epic/<name>` branch. Confirm the layer order still holds after the renames (`bash references/scripts/stack-plan.sh <name> --check`), then create the worktree on the bottom layer's branch:
```bash
git worktree add ../epic-<name> -b epic/<name>/<bottom_N> main
```

**Step 6 — Create github-mapping.md:**
```markdown
# GitHub Issue Mapping
Epic: #<N> - https://github.com/<repo>/issues/<N>
Tasks:
- #<N>: <title> - https://github.com/<repo>/issues/<N>
Synced: <datetime>
```

**Output:**
```
✅ Synced epic <name> to GitHub
  Epic: #<N>
  Tasks: N sub-issues
  Worktree: ../epic-<name>
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

Comment format:
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

## Submitting a Task (stack delivery)

**Trigger**: A task of a `delivery: stack` epic is finished — e.g. "submit issue N", "open the PR for issue N", or all of its streams have completed.

Stack delivery replaces "Closing an Issue": CCPM submits the layer, and the issue closes when its PR merges.

### Preflight
- The task is the next layer to submit: the task directly below it (by `position`) is `in-review` or `closed`.
- Run the layer gate from `conventions.md` → Test Gates on the task's branch `epic/<name>/<N>` in `../epic-<name>/`. If it does not pass: "❌ Cannot submit #<N>: <failing or missing test cases>." Proceed only with the user's explicit approval.
- No uncommitted changes in the worktree.

### Process

1. Push the layer branch: `git push -u origin epic/<name>/<N>`
2. Write the PR body to `/tmp/pr-body.md`:
```markdown
Closes #<N>

## Stack
Layer <position> of <total> in epic #<epic_N>
- Below: #<PR of the layer below> (or: none, based on main)
- Above: #<N of the next task> (not submitted yet)

## Acceptance Criteria
<AC lines from the task file>

## Test Cases
<TC IDs and the TS/AC each covers, or N/A — <reason>>

## Tests
`<test command>` — <passed / passed except baseline failures: ...>

Suggested merge method: squash (keeps the Red commits out of main's history)
```
3. Create the PR (see `conventions.md` → Pull Request Operations), base = the layer below's branch, or `main` for the bottom layer:
```bash
pr_url=$(gh pr create --repo "$REPO" --base <base_branch> --head epic/<name>/<N> \
  --title "<task_name>" --body-file /tmp/pr-body.md)
```
4. From the second layer on, link the stack when possible: re-run `gh stack link` with every submitted layer's branch, bottom to top, or use the stacks REST endpoint (create the stack from the first two PRs, then `POST repos/<owner>/<repo>/stacks/<stack_number>/add` for each later PR). If neither is available, leave the PRs unlinked.
5. In the task file set `status: in-review`, `pr: <pr_url>`, `updated: <now>`.
6. Add the PR to the epic issue's task line:
```bash
gh issue view <epic_N> --json body -q .body > /tmp/epic-body.md
sed -i "s|^- \[ \] #<N>\(.*\)$|- [ ] #<N>\1 (PR <pr_url>)|" /tmp/epic-body.md
gh issue edit <epic_N> --body-file /tmp/epic-body.md
```

**Output:**
```
✅ Submitted #<N> as layer <position>/<total>: <pr_url>
  Next layer: #<next_N> — "start working on issue <next_N>"
```

If a submitted layer needs another change, follow `conventions.md` → Changing a Lower Layer.

---

## Closing an Issue

**Trigger**: User marks a task complete. Merge delivery only; with stack delivery, see Submitting a Task.

### Preflight
- Run the closing gate from `conventions.md` → Test Gates in the epic worktree (`../epic-<name>/`). If it does not pass: "❌ Cannot close #<N>: <failing or missing test cases>." Proceed only with the user's explicit approval.

### Process

1. Find the local task file (`.claude/epics/*/<N>.md`).
2. Update frontmatter: `status: closed`, `updated: <now>`.
3. Post completion comment:
```bash
echo "✅ Task completed — all acceptance criteria met, all test cases passing." | gh issue comment <N> --body-file -
# if the closing gate was passed by the user's approval instead, post:
# "✅ Task closed with user approval — not passing: <failing or missing test cases>"
gh issue close <N>
```
4. Check off the task in the epic issue body:
```bash
gh issue view <epic_N> --json body -q .body > /tmp/epic-body.md
sed -i "s/- \[ \] #<N>/- [x] #<N>/" /tmp/epic-body.md
gh issue edit <epic_N> --body-file /tmp/epic-body.md
```
5. Recalculate and update epic progress: `progress = closed_tasks / total_tasks * 100`

---

## Merging an Epic

**Trigger**: User wants to merge a completed epic back to main.

With stack delivery, CCPM does not merge: the epic is done when every task's PR has merged. Instead of the process below:
1. Read each task issue's state and each task PR's state (see `conventions.md` → Pull Request Operations). If any issue is open or any PR is not merged, list them and stop.
2. Set every task to `status: closed`, check them off in the epic issue body, and set the epic's `progress: 100%`.
3. Clean up and archive:
```bash
git worktree remove ../epic-<name>
for b in $(git branch --list "epic/<name>/*" --format='%(refname:short)'); do
  git branch -D "$b"                          # PR merged (step 1); a squash merge leaves the branch unmerged to git
  git push origin --delete "$b" 2>/dev/null   # GitHub may already have deleted it
done
mkdir -p .claude/epics/archived/
mv .claude/epics/<name> .claude/epics/archived/
gh issue close <epic_N> -c "Epic completed: all task PRs merged"
```
4. Update epic.md frontmatter: `status: completed`.

With merge delivery:

### Preflight
- Verify worktree `../epic-<name>` exists.
- Check for uncommitted changes in the worktree — block if dirty.
- Warn if any task issues are still open.
- Run the merging gate from `conventions.md` → Test Gates in the worktree. If it does not pass, block the merge unless the user explicitly approves.

### Process

```bash
# From worktree: run the full test suite (command from the epic's Test Strategy)
cd ../epic-<name>
# e.g. npm test / pytest / cargo test / go test — stop here if the gate does not pass and the user has not approved proceeding

# From main repo:
git checkout main && git pull origin main
git merge epic/<name> --no-ff -m "Merge epic: <name>"
git push origin main

# Cleanup
git worktree remove ../epic-<name>
git branch -d epic/<name>
git push origin --delete epic/<name>

# Archive
mkdir -p .claude/epics/archived/
mv .claude/epics/<name> .claude/epics/archived/

# Close GitHub issues
epic_issue=$(grep 'github:' .claude/epics/archived/<name>/epic.md | grep -oE '[0-9]+$')
gh issue close $epic_issue -c "Epic completed and merged to main"
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

The fix is test-first: TC-1 is a regression test that reproduces the bug. It is written and confirmed failing before any fix (Red), then the fix makes it pass (Green).

```markdown
---
name: Bug: <short description>
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

## Test Cases
| ID | Covers | Level | Given / When / Then | Test location |
|---|---|---|---|---|
| TC-1 | Regression #<original_N> | unit/integration/e2e | Given <state from Steps to Reproduce>, when <action>, then <expected behavior> | <path/to/test_file> |

## Acceptance Criteria
- [ ] Regression test TC-1 reproduces the bug and fails before the fix
- [ ] Bug is fixed — TC-1 passes
- [ ] Original issue #<original_N> behaviour is unaffected — its test cases still pass

## Effort Estimate
- Size: XS/S
```

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

The issue body should open with `Fixes / follow-up to #<original_N>` so GitHub auto-links them.

**Step 4 — Update the local file** with the GitHub issue number and rename to `<new_N>.md`.

With stack delivery, the bug task becomes the new top layer: run `bash references/scripts/stack-plan.sh <epic_name> --write`.

**Output:**
```
✅ Bug issue created: #<new_N> — "Bug: <short description>"
  Linked to: #<original_N>
  Epic: <epic_name>

Start fixing it: "start working on issue <new_N>"
```
