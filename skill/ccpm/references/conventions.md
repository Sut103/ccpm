# Conventions — File Formats, Paths & Rules

Read this before doing any file operations across all phases.

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
name: <feature-name>        # kebab-case, matches filename
description: <one-liner>    # used in lists and summaries
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
delivery: merge             # merge | stack (see Delivery Modes); missing means merge
---
```

### Task (.claude/epics/<name>/<N>.md)
```yaml
---
name: <Task Title>
status: open | in-progress | in-review | closed   # in-review: stack delivery only
created: <ISO 8601>
updated: <ISO 8601>
github: https://github.com/<owner>/<repo>/issues/<N>  # set on sync
depends_on: []              # issue numbers this must wait for
parallel: true              # can run concurrently with non-conflicting tasks
conflicts_with: []          # issue numbers that touch the same files
position: 1                 # stack delivery only: layer in the stack, 1 = bottom (set by stack-plan.sh)
pr: https://github.com/<owner>/<repo>/pull/<N>  # stack delivery only: set on submit
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

---

## TDD & Test Traceability

Development is test-driven by default. Acceptance criteria are refined step by step as work moves from PRD to epic to task, and every test case traces back to the requirement it proves.

### ID Scheme

| ID | Defined in | Section | Describes |
|---|---|---|---|
| `US-<n>` | PRD | `## User Stories` | A user story |
| `AC-<n>` | PRD | `## Acceptance Criteria` | Observable behavior that proves a story is done (Given/When/Then, no implementation details) |
| `TS-<n>` | Epic | `## Test Strategy` → `### Acceptance Test Matrix` | A test scenario that proves one AC at a chosen level (unit / integration / e2e) |
| `TC-<n>` | Task | `## Test Cases` | A concrete test: precondition, input, expected output, test file location |

IDs are numbered per file (`AC-1`, `AC-2`, ... in a PRD; `TC-1`, `TC-2`, ... in each task) and are not reused after deletion. Each TC names the TS it covers (or an exception below), each TS names its AC, and each AC names its US.

### Red → Green → Refactor

Implementation of a task follows this cycle:

1. **Red** — write tests for the task's test cases before any production code. Run them and confirm they fail for the expected reason (a failed assertion or missing behavior). A failure caused by a syntax error, a bad import or a broken test setup is not Red; fix the test first. If the test cannot compile or import because the code under test does not exist yet, first add a minimal stub (signature only, body throws "not implemented") and commit it with the tests, so the suite still builds for everyone else in the worktree; the stub prepares Red and is not production code.
2. **Green** — write the minimal production code that makes the failing tests pass. Do not add behavior that no test asks for: every change that adds behavior is driven by a test case.
3. **Refactor** — clean up code and tests while every test stays green.

Commit at each step: `Issue #<N>: add failing tests for TC-1..TC-3`, `Issue #<N>: <specific change>`, `Issue #<N>: refactor <area>`. The Red commit is an intended exception to any "run tests before committing" rule; if a pre-commit hook rejects it, commit the failing tests together with the Green change instead of bypassing the hook. Never weaken or delete a test to make it pass.

### Writing Test Cases

- Use Given / When / Then.
- Use concrete values: `Given a cart with 2 items at $10, when a 10% coupon is applied, then the total is $18.00`, not `then the total is correct`.
- One behavior per test case. Cover the failure paths and edge cases the AC implies (invalid input, empty state, limits), not only the happy path.
- Fill `Test location` with the planned test file, following the project's existing test layout. It is a plan, not a record: do not update it after the test exists.
- Escape `|` as `\|` inside table cells.

### Tests Are the Record

The `## Test Cases` table is the specification written before code exists. Once tests exist, the test code and the test run are the source of truth. Do not record per-test-case status (passing, failing, not written) in any file or issue comment; run the tests instead.

To keep the link between a test case and its test in the code, tag the test with `[#<N> TC-<n>]` in its name, e.g. `it("[#1234 TC-2] rejects a duplicate email")`. Where test names cannot hold the tag (e.g. Go or pytest function names), put it in a comment on the line directly above the test. The brackets keep `TC-1` from matching `TC-10`; `grep -rnF "[#1234 TC-2]"` finds the test.

### Changing Test Cases

Update a level above only when a change crosses that level's granularity:

| Change | Update |
|---|---|
| Concrete values, split or added TC | Task `## Test Cases` only |
| What a scenario proves, its test level, or which ACs have a scenario | Epic `### Acceptance Test Matrix` too |
| What an acceptance criterion means | PRD `## Acceptance Criteria` too, then flow down |

Which task covers a TS is recorded only in the task's `Covers` column.

### Test Gates

The closing gate (closing an issue) and the merging gate (merging an epic) both run the project's full test suite (command from the epic's `### Test Levels & Tooling`) in the epic worktree. The gate passes when:

- every `TC-<n>` of the task (closing) or of every task (merging) has a test, found by its `[#<N> TC-<n>]` tag, and that test passes; and
- no other test fails, except tests listed as baseline failures in `### Test Levels & Tooling` and, when closing, tests belonging to other open tasks of the epic.

For a task whose Test Cases are `N/A — <reason>`, only the second condition applies. If the gate does not pass, report what fails and why to the user; proceed only with their explicit approval.

With stack delivery, the **layer gate** replaces the closing gate and there is no merging gate. It runs in the epic worktree on the task's layer branch, before the task is submitted, and passes when every `TC-<n>` of the task has a passing test (as above) and no other test fails except baseline failures. Tests of other open tasks are not exempt: tasks above this layer are not on its branch, and every task below it is already part of it.

### Exceptions

TDD is the default, not an absolute.

- **No observable behavior**: a change that adds no behavior a test could observe (e.g. documentation, configuration with nothing to assert, a time-boxed spike) needs no test case. For a task, write `N/A — <reason>` in `## Test Cases` and mark the TDD items in Definition of Done as N/A; for a stream, write it in the stream's **Test Cases** field in the analysis. Omitting the section or field, or writing N/A without a reason, is not allowed. If a spike leads to production code, that code goes into a follow-up task with its own test cases.
- **Test already passes** (a characterization test for a refactor, or behavior an earlier task already delivered): the test is still committed in Red's place, with the reason in the commit message instead of "failing", e.g. `Issue #<N>: add tests for TC-4 (already passing: characterizes current behavior)`.
- **No PRD acceptance criterion** (setup, infrastructure, refactoring): write `AC: n/a (<reason>)` in the task's `## Acceptance Criteria`, and `n/a (<reason>)` in the `Covers` column of its test cases.
- **Bug fix**: the regression test's `Covers` is `Regression #<original_N>` instead of a TS.

---

## Datetime Rule

Always get real current datetime from the system — never use placeholder text:
```bash
date -u +"%Y-%m-%dT%H:%M:%SZ"
```

---

## Frontmatter Update Pattern

When updating a single frontmatter field in an existing file (only lines inside the frontmatter are touched):
```bash
awk -v k="<field>" -v v="<value>" '
  NR==1 && /^---$/ {fm=1; print; next}
  fm && /^---$/    {fm=0}
  fm && index($0, k":")==1 {print k": "v; next}
  {print}' <file> > <file>.tmp && mv <file>.tmp <file>
```

When stripping frontmatter to get body content for GitHub (body `---` lines are kept):
```bash
awk 'NR==1 && /^---$/ {fm=1; next} fm && /^---$/ {fm=0; next} !fm' <file> > /tmp/body.md
```

Do not use `sed '1,/^---$/d; 1,/^---$/d'` or `sed "/^<field>:/c\\..."`: on GNU sed the former also deletes the body (up to the next `---`, or all of it), and the latter rewrites matching lines in the body too.

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

### Authentication
Don't pre-check authentication. Run the `gh` command and handle failure:
```bash
gh <command> || echo "❌ GitHub CLI failed. Run: gh auth login"
```

### Getting Issue Numbers
```bash
# From a task file's github field:
grep 'github:' <file> | grep -oE '[0-9]+$'
```

---

## Delivery Modes

The epic's `delivery` field decides how finished work reaches main. It is chosen when the epic is created and does not change once the epic is synced.

| | `merge` (default) | `stack` |
|---|---|---|
| Branches | One branch per epic: `epic/<name>` | One branch per task (layer): `epic/<name>/<N>`; no `epic/<name>` branch |
| Pull requests | None; the epic branch is merged into main | One PR per task, chained into a single linear stack |
| Task order | `depends_on`; `parallel` tasks run concurrently | Every task is one layer of one stack, in `position` order; tasks run one after another, streams inside a task still run in parallel |
| Task done | Closed by "Closing an Issue" | `in-review` when its PR is submitted; the issue closes when the PR merges (`Closes #<N>`) |
| Gate | Closing gate per task, merging gate per epic | Layer gate per task (see Test Gates) |
| Epic end | `git merge --no-ff` into main | Confirm every task issue is closed, clean up, archive. CCPM never merges PRs |

### Stack Layout

- `bash references/scripts/stack-plan.sh <name>` prints the stack; `--write` stores each task's `position`; `--check` fails when stored positions do not match the plan.
- Order: tasks that have a `position` keep it; the others go on top in `depends_on` order, lowest task number first. A cycle, or a dependency that is not below the task depending on it, is an error.
- `parallel` and `conflicts_with` do not affect the order: all layers are sequential.
- A task can start when the task directly below it is `in-review` or `closed`. The bottom layer can start at once.
- Layer `<N>` lives on branch `epic/<name>/<N>`. Its PR base is the branch of the layer below, or main for the bottom layer.

### Pull Request Operations

Use `gh` or the GitHub MCP server, whichever the harness has. Git itself is always required for branches, rebases and pushes.

| Operation | gh | GitHub MCP |
|---|---|---|
| Create a PR / change its base | `gh pr create --base <base> --head <branch>` / `gh pr edit <N> --base <base>` | `create_pull_request` / `update_pull_request` |
| Link PRs into a GitHub stack | `gh stack link <branches...>` (gh-stack extension) or `gh api -X POST repos/<owner>/<repo>/stacks -H "X-GitHub-Api-Version: 2026-03-10" -F "pull_requests[]=<N1>" -F "pull_requests[]=<N2>" ...` (bottom to top) | No tool: leave the PRs unlinked |
| Read an issue's state | `gh issue view <N> --json state` | `issue_read` |
| Read a PR's state | `gh pr view <N> --json state` | `pull_request_read` |

Linking is optional. Unlinked PRs whose bases form the chain still show each layer's own diff; only GitHub's stack features (stack view, merging several layers at once, rebasing upper layers after a merge) are missing.

### Changing a Lower Layer

When a submitted layer needs a change (a bug found while building a layer above it, or feedback on its PR):

1. Commit the fix on that layer's branch, test-first as usual.
2. Rebase the layers above onto it: `git rebase --update-refs <fixed-branch> <top-branch>` (Git 2.38+; it also moves the layer branches in between), or `gh stack rebase --upstack` with the gh-stack extension.
3. Run the layer gate on every layer above the fixed one.
4. Push each rewritten branch with `git push --force-with-lease origin <branch>`.

---

## Git / Worktree Conventions

- One branch per epic: `epic/<name>` (stack delivery: one branch per layer, see Delivery Modes)
- Worktrees live at `../epic-<name>/` (sibling to project root)
- Always start branches from an up-to-date main:
  ```bash
  git checkout main && git pull origin main
  git worktree add ../epic-<name> -b epic/<name>
  ```
- Commit format inside epics: `Issue #<N>: <description>`
- Never use `--force` in any git operation. The exceptions, with stack delivery and only on the epic's own layer branches: `git push --force-with-lease` after a rebase (see Changing a Lower Layer), and `git branch -D` once the layer's PR has merged (see `sync.md` → Merging an Epic)

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
