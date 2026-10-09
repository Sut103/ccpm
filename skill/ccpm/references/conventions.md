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
---
```

### Task (.claude/epics/<name>/<N>.md)
```yaml
---
name: <Task Title>
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

IDs are numbered per file (`AC-1`, `AC-2`, ... in a PRD; `TC-1`, `TC-2`, ... in each task) and are not reused after deletion. Each TC names the TS it covers, each TS names its AC, and each AC names its US.

### Red → Green → Refactor

Implementation of a task follows this cycle:

1. **Red** — write tests for the task's test cases before any production code. Run them and confirm they fail for the expected reason (a failed assertion or missing behavior). A failure caused by a syntax error, a bad import or a broken test setup is not Red; fix the test first.
2. **Green** — write the minimal production code that makes the failing tests pass. Do not add behavior that no test asks for.
3. **Refactor** — clean up code and tests while every test stays green.

Commit at each step: `Issue #<N>: add failing tests for TC-1..TC-3`, `Issue #<N>: <specific change>`, `Issue #<N>: refactor <area>`. A task is not done until its test cases and the project's full test suite pass. Never weaken or delete a test to make it pass.

### Writing Test Cases

- Use Given / When / Then.
- Use concrete values: `Given a cart with 2 items at $10, when a 10% coupon is applied, then the total is $18.00`, not `then the total is correct`.
- One behavior per test case. Cover the failure paths and edge cases the AC implies (invalid input, empty state, limits), not only the happy path.
- Fill `Test location` with the test file (and test name if known), following the project's existing test layout.

### Exceptions

TDD is the default, not an absolute. A task with no testable behavior (documentation only, configuration with nothing to assert, a time-boxed spike) writes `N/A — <reason>` in its `## Test Cases` section and marks the TDD items in its Definition of Done as N/A. Omitting the section, or writing N/A without a reason, is not allowed. If a spike leads to production code, that code goes into a follow-up task with its own test cases.

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
