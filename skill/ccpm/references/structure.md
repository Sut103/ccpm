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
- Tests: unit, integration, e2e
- Docs: README, API docs, changelogs

**Parallelization strategy by epic size:**
- Small (<5 tasks): create sequentially
- Medium (5–10 tasks): batch into 2–3 groups, spawn parallel Task agents
- Large (>10 tasks): analyze dependencies first, launch parallel agents (max 5 concurrent), create dependent tasks after prerequisites

When writing each task, populate the テスト計画（先に書く — TDD）section by turning each 受け入れ基準 item into a concrete unit test description — for application-code tasks, this test plan must exist before implementation begins (tests are planned alongside the implementation plan, not after it).

For parallel creation, use the Task tool:
```yaml
Task:
  description: "Create task files batch N"
  subagent_type: "general-purpose"
  prompt: |
    Create task files for epic: <name>
    Tasks to create: [list 3-4 tasks]
    Save to: .claude/epics/<name>/001.md, 002.md, etc.
    Follow the task file format exactly.
    Return: list of files created.
```

### Task File Format

```markdown
---
name: "<Task Title>"
status: open
created: <run: date -u +"%Y-%m-%dT%H:%M:%SZ">
updated: <same as created>
github: (will be set on sync)
depends_on: []
parallel: true
conflicts_with: []
---

# タスク: <Task Title>

## 概要

## 受け入れ基準
- [ ]

## テスト計画（先に書く — TDD）
アプリケーションコード（ビジネスロジック・サービス・コンポーネント）のみが対象。受け入れ基準の各項目につき単体テストを1つ列挙する。このタスクが後で複数streamに分割され（execute.mdのIssue Analysis参照）、一部のstreamが純粋なconfig/docs/infra/生成コードである場合は、アプリケーションコード部分のみテストを列挙する — タスク全体を`N/A`とするのは、その全てが非アプリケーションコードの場合のみ。タスク全体が非アプリケーションの場合のみ `N/A — 非アプリケーションタスク` と記載する。
- [ ] <単体テスト — 上記の受け入れ基準に対応>

## 技術詳細

## 依存関係

## 見積もり工数
- 規模: XS/S/M/L/XL
- 時間: N

## 完了の定義
- [ ] RED: 受け入れ基準ごとに失敗する単体テストを書く（アプリケーションコードのみ）
- [ ] GREEN: 実装によって全テストを成功させる
- [ ] リファクタリング完了、テストは引き続き成功
- [ ] コードレビュー済み（execute.mdの必須レビュー手順を参照）
```

Write this in Japanese per conventions.md § Language & Content Style (the single source of truth for what stays in English vs. Japanese).

**Numbering**: sequential 001.md, 002.md, etc. Tasks are renamed to GitHub issue numbers after sync — do not hard-code dependencies by filename, use the `depends_on` array.

### After Creating All Tasks

Append a summary to the epic file:

```markdown
## 作成されたタスク
- [ ] 001.md - <Title>（parallel: true/false）
- [ ] 002.md - <Title>（parallel: true/false）

合計タスク数: N
並列タスク数: N
逐次タスク数: N
見積もり合計工数: N時間
```

**After completion**: Confirm "✅ Created N tasks for epic: <name>" and suggest: "Ready to push to GitHub? Say: sync the <name> epic"

---

## Dependency Rules
- `depends_on` lists task numbers that must complete before this task can start.
- `parallel: true` means the task can run concurrently with others it doesn't conflict with.
- `conflicts_with` lists tasks that touch the same files — these cannot run in parallel.
- Circular dependencies are an error — check before finalizing.
