---
name: ccpm
description: "CCPM - 仕様駆動のプロジェクト管理: PRD → Epic → GitHub Issues → 並列エージェント → 出荷済みコード。ソフトウェア提供工程の全般で使用: PRD の作成 (「X の PRD を作成」「X を計画」「X の範囲を整理」 / 'write a PRD for X', 'let's plan X', 'scope this out')、PRD の Epic 化、Epic の Task 分解、GitHub への Sync (「X の Epic を Sync」「Task を GitHub へ push」 / 'sync the X epic', 'push tasks to github')、Issue への着手 (「Issue N に着手」 / 'start working on issue N')、並列 Stream の分析、Task の Stacked PR としての Submit (「Issue N を Submit」「Issue N の PR を作成」 / 'submit issue N', 'open the PR for issue N')、Standup (「スタンドアップ」 / 'standup')、状況確認 (「次の作業」「阻害中の作業」「進行中の作業」 / 'what's next', 'what's blocked', 'what are we working on')、Issue のクローズ、Epic のマージ。'ccpm' や 'PRD' の明示がなくとも、機能の出荷、作業管理、進捗追跡に関する話題では常に使用。使用対象外: コードのデバッグ、Test の作成、PR のレビュー、提供工程の文脈を伴わない単純な GitHub Issue/PR 操作。"
---

# CCPM - Claude Code Project Manager

仕様駆動の開発手順: PRD → Epic → GitHub Issues → 並列エージェント → 出荷済みコード。

## 基本思想

要件は個人の記憶ではなくファイルに保持。全機能は PRD に始まり、技術 Epic となり、GitHub Issue へ分解され、完全な追跡性を保ちつつ並列エージェントが実行する。

各 Epic は Delivery Mode を選択: `merge` (既定) は Epic ブランチを main へマージ。`stack` は全 Task をそれぞれ一つの Pull Request として、単一の直線的 stack で Submit。`references/conventions.md` → Delivery Modes 参照。

開発は既定で Test 駆動。Acceptance Criteria は各段階で詳細化 — PRD の Acceptance Criteria (`AC`) → Epic の Test Scenario (`TS`) → Task の Test Case (`TC`) — し、エージェントは失敗する Test を、それを通過させるコードより先に作成。`references/conventions.md` → TDD & Test Traceability 参照。

## ファイル規約

全作業の前に `references/conventions.md` を読み、パス規約、Frontmatter スキーマ、GitHub 操作規則を確認。全 Phase に適用。

## The Five Phases

### 1. Plan — 要件定義
**対象**: 新機能、製品要件、作業範囲の定義をユーザーが要望。
**読込**: `references/plan.md`
**内容**: 誘導型ブレインストーミングによる PRD (Acceptance Criteria 付き) の作成、PRD の技術 Epic (各 Criterion を Test Scenario へ対応付ける Test Strategy 付き) への変換。

### 2. Structure — 分解
**対象**: 既存の Epic を具体的な Task へ分解する必要あり。
**読込**: `references/structure.md`
**内容**: 依存関係、並列化、具体的な Test Case を備えた連番 Task ファイルへの Epic 分解。

### 3. Sync — GitHub への反映
**対象**: ローカルの Epic/Task の GitHub Issue 化、進捗のコメント投稿、stack delivery の Epic における完了 Task の Pull Request 作成、またはバグ発見時の関連 Issue 作成が必要。
**読込**: `references/sync.md`
**内容**: Epic Sync (Epic + Task → GitHub Issue)、Issue Sync (進捗コメント)、Task の Stacked PR としての Submit、Issue/Epic のクローズ、完了済み Issue に対するバグ報告。

### 4. Execute — 構築開始
**対象**: 一つ以上の GitHub Issue について、並列エージェントによる作業開始をユーザーが要望。
**読込**: `references/execute.md`
**内容**: Issue 分析 (並列 Stream の特定)、Test 先行 (Red → Green → Refactor) で作業する並列エージェントの起動、Worktree の調整。

### 5. Track — 現況把握
**対象**: 状況、Standup Report、阻害中の作業、次の作業、状態検証をユーザーが要望。
**読込**: `references/track.md`
**内容**: 状況、Standup、検索、進行中の作業、次の優先事項、阻害中の項目、検証。

---

## Script-First Rule

確定的な操作 (推論を要さず、読込と報告のみの処理) は、手作業ではなく必ず bash スクリプトを直接実行:

| ユーザーの要望 | 実行スクリプト |
|---|---|
| プロジェクト状況 | `bash references/scripts/status.sh` |
| Standup Report | `bash references/scripts/standup.sh` |
| Epic 一覧 | `bash references/scripts/epic-list.sh` |
| Epic 詳細 | `bash references/scripts/epic-show.sh <name>` |
| Epic 状況 | `bash references/scripts/epic-status.sh <name>` |
| PRD 一覧 | `bash references/scripts/prd-list.sh` |
| PRD 状況 | `bash references/scripts/prd-status.sh` |
| Issue/Task の検索 | `bash references/scripts/search.sh <query>` |
| 進行中の作業 | `bash references/scripts/in-progress.sh` |
| 次の作業 | `bash references/scripts/next.sh` |
| 阻害中の作業 | `bash references/scripts/blocked.sh` |
| プロジェクト状態の検証 | `bash references/scripts/validate.sh` |
| Stack の Layer 順序 (stack delivery) | `bash references/scripts/stack-plan.sh <name>` |

LLM は推論を要する作業 (PRD の作成、並列性の分析、エージェントの起動、更新内容の統合) に使用。

---

## 早見表

```
機能の計画:         「X を構築したい」「X の PRD を作成」
Epic 化:            「X の PRD を Epic 化」
分解:               「X の Epic を Task に分解」
GitHub への Sync:   「X の Epic を GitHub へ push」
Issue への着手:     「Issue 42 に着手」
状況確認:           「現在の状況」 / 「スタンドアップ」
次の作業:           「次の作業」
Task の Submit:     「Issue 42 を Submit」 (stack delivery)
Epic のマージ:      「X の Epic をマージ」
バグ報告:           「Issue 42 でバグを発見」 / 「Issue 42 の検証で X が判明」
```
