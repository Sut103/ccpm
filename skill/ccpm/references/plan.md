# Plan — 要件定義

本 Phase では、構想を構造化した PRD へ整理し、さらに PRD を分解可能な技術 Epic へ変換する。

---

## Writing a PRD

**起動条件**: 新機能、製品要件、作業領域の計画をユーザーが要望。

### Preflight
- `.claude/prds/<name>.md` の既存有無を確認。既存の場合、続行前に上書きの可否を確認。
- `.claude/prds/` directory の存在を確認。不在の場合は作成。
- 機能名は kebab-case (小文字、英字・数字・ハイフンのみ、先頭は英字) 必須。違反時: 「❌ 機能名は kebab-case 必須。例: user-auth, payment-v2」

### Process

記述開始前に、実質的なブレインストーミングを実施。ユーザーへの質問事項:
- 解決対象の課題
- 影響を受けるユーザー
- 成功の定義
- 各 Story の完了判定方法 (システム外部から観測・確認可能な結果)
- 明示的な対象外事項
- 制約 (技術、期間、資源)

その後、次の Frontmatter と構成で `.claude/prds/<name>.md` を作成。

```markdown
---
name: <feature-name>
description: <one-line summary>
status: backlog
created: <run: date -u +"%Y-%m-%dT%H:%M:%SZ">
---

# PRD: <feature-name>

## Executive Summary
## Problem Statement
## User Stories
## Acceptance Criteria
## Functional Requirements
## Non-Functional Requirements
## Success Criteria
## Constraints & Assumptions
## Out of Scope
## Dependencies
```

**User Story** には ID を付与: `US-1: As a <role>, I want <capability> so that <benefit>.`

**Acceptance Criteria** は、Story ごとに完了を証明する観測可能な振る舞いを記述。Test 連鎖の起点 (PRD `AC` → Epic `TS` → Task `TC`。`conventions.md` → TDD & Test Traceability 参照):

```markdown
## Acceptance Criteria
- AC-1 (US-1): Given <context>, when <action>, then <observable outcome>
- AC-2 (US-1): Given <context>, when <invalid action>, then <error the user sees>
```

ユーザー視点で記述し、実装詳細 (クラス名、テーブル、endpoint) は含めない。

**保存前の品質基準:**
- 全セクションに placeholder 文字列なし
- 全 User Story に ID (`US-<n>`) と一つ以上の Acceptance Criterion (`AC-<n>`) あり
- Acceptance Criteria は Given/When/Then 形式、システム外部から観測可能、実装詳細なし
- 検証必須の非機能要件 (性能、セキュリティ、上限) も Acceptance Criteria として記述
- Success Criteria は計測可能
- Out of Scope を明示的に列挙

**作成後**: 「✅ PRD 作成完了: `.claude/prds/<name>.md`」と報告し、「技術 Epic を作成する場合の指示例: <name> の PRD を Epic 化」と提案。

---

## Parsing a PRD into a Technical Epic

**起動条件**: 既存 PRD の技術的実装計画への変換をユーザーが要望。

### Preflight
- `.claude/prds/<name>.md` の存在と Frontmatter (name, description, status, created) の妥当性を確認。
- `.claude/epics/<name>/epic.md` の既存有無を確認。既存の場合は上書きの可否を確認。

### Process

PRD を全文読了後、`.claude/epics/<name>/epic.md` を作成。

```markdown
---
name: <feature-name>
status: backlog
created: <run: date -u +"%Y-%m-%dT%H:%M:%SZ">
progress: 0%
prd: .claude/prds/<name>.md
github: (will be set on sync)
delivery: merge
---

# Epic: <feature-name>

## Overview
## Architecture Decisions
## Technical Approach
### Frontend Components
### Backend Services
### Infrastructure
## Implementation Strategy
## Test Strategy
### Test Levels & Tooling
### Acceptance Test Matrix
## Task Breakdown Preview
## Dependencies
## Success Criteria (Technical)
## Estimated Effort
```

**Test Strategy** では、PRD の各 Acceptance Criterion を Test Scenario へ詳細化。

- `### Test Levels & Tooling` — Test framework、全 test suite の実行コマンド、Test の配置場所。プロジェクトの既存資産 (`package.json` の scripts、`pytest.ini`、`go test`、`Cargo.toml` 等) を検出・再利用。test suite を一度実行し、既に失敗している Test を baseline failure として列挙。Test 基盤が未整備の場合は導入を提案し、導入用の Setup Task を計画。他の全 Task は当該 Task に依存。
- `### Acceptance Test Matrix` — Scenario ごとに一行:

```markdown
| AC | Scenario | Level |
|---|---|---|
| AC-1 | TS-1: valid signup creates an account and sends a welcome email | integration |
| AC-1 | TS-2: signup form shows a confirmation after submit | e2e |
| AC-2 | TS-3: duplicate email is rejected with an error message | unit |
```

Criterion を証明可能な最低水準を選択。e2e は全層にわたるフローに限定。

**Delivery**: 完了した作業の main への反映方法をユーザーに確認し、`delivery` を設定 (`conventions.md` → Delivery Modes 参照)。
- `merge` (既定): 全 Task 完了時に Epic branch を main へ merge。
- `stack`: 各 Task を個別の Pull Request として Submit し、全体で単一の直線的 stack を構成。Task は逐次実行 (Task 内の Stream は引き続き並列実行)。GitHub repository と、`gh` または GitHub MCP サーバーが必要。

`## Task Breakdown Preview` には、各 Task が担う予定の `TS-<n>` ID を列挙。分解用の計画であり、以後の保守は不要。Task 作成後は、各 Task の `## Test Cases` の `Covers` 列が記録の正本。

**主要制約:**
- Task 総数は 10 以下を目標。網羅性より簡潔性を優先。
- 新規コード作成の前に既存機能の活用余地を検討。
- Task Breakdown Preview で並列化の余地を特定。
- PRD の全 Acceptance Criterion を、一つ以上の Scenario と共に Acceptance Test Matrix へ記載。

**作成後**: 「✅ Epic 作成完了: `.claude/epics/<name>/epic.md`」と報告し、「Task へ分解する場合の指示例: <name> の Epic を分解」と提案。

---

## Editing a PRD or Epic

先にファイルを読み、Frontmatter を全て保持したまま対象箇所のみ編集。Frontmatter の `updated` field を現在日時へ更新。

Acceptance Criteria、Scenario、Test Case の変更時は、`conventions.md` → Changing Test Cases に従い更新対象の階層を判断。
