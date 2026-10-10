# Structure — Break Down an Epic

本 Phase では、技術 Epic を、依存関係と並列化の情報を備えた具体的な連番 Task ファイルへ変換する。

---

## Epic Decomposition

**起動条件**: Epic の実行可能な Task への分解をユーザーが要望。

### Preflight
- `.claude/epics/<name>/epic.md` の存在と Frontmatter の妥当性を確認。
- Epic ディレクトリに連番 Task ファイル (001.md, 002.md...) が既存の場合、一覧を提示し、再作成前に削除の可否を確認。
- Epic の status が "completed" の場合、続行前にユーザーへ警告。

### Process

Epic を全文読了。並列性を分析し、ファイル競合なしに同時進行可能な作業単位を特定。

**検討対象の Task 種別:**
- Setup: 環境、雛形、依存パッケージ
- Data: モデル、スキーマ、マイグレーション
- API: エンドポイント、サービス、連携
- UI: コンポーネント、ページ、スタイル
- Docs: README、API 文書、変更履歴

Test は独立した Task 種別ではない。各 Task が自身の振る舞いに対する Test を先行作成 (`conventions.md` → TDD & Test Traceability 参照)。Epic の Acceptance Test Matrix の全 Test Scenario (`TS-<n>`) を、当該振る舞いを実装する Task で網羅。複数 Task にまたがる e2e Scenario は、そのフローを完成させる Task (通常は依存連鎖の末尾) へ割当。Epic が Test 基盤導入用の Setup Task を計画している場合、他の全 Task は当該 Task を `depends_on` に記載。

**Epic 規模別の並列化方針:**
- 小 (5 Task 未満): 逐次作成
- 中 (5–10 Task): 2–3 群に分け、並列の Task エージェントを起動
- 大 (10 Task 超): 先に依存関係を分析し、並列エージェントを起動 (同時実行は最大 5)、依存先の完了後に依存側 Task を作成

並列作成には Task ツールを使用:
```yaml
Task:
  description: "Task ファイル作成 第 N 群"
  subagent_type: "general-purpose"
  prompt: |
    Epic <name> の Task ファイルを作成。
    作成対象: [3-4 件の Task と、各 Task が担う TS ID]
    保存先: .claude/epics/<name>/001.md, 002.md 等
    Task ファイル形式を厳守し、割当済みの全 TS に具体的な Test Case を記述。
    返却値: 作成したファイルの一覧。
```

### Task File Format

```markdown
---
name: <Task Title>
status: open
created: <run: date -u +"%Y-%m-%dT%H:%M:%SZ">
updated: <same as created>
github: (will be set on sync)
depends_on: []
parallel: true
conflicts_with: []
---

# Task: <Task Title>

## Description

## Acceptance Criteria
- [ ] AC-<n>: <PRD criterion this task satisfies, fully or in part>
<!-- PRD の Criterion がない Task の場合: AC: n/a (<reason>)、Covers は n/a (<reason>) -->

## Test Cases
| ID | Covers | Level | Given / When / Then | Test location |
|---|---|---|---|---|
| TC-1 | TS-<n> (AC-<n>) | unit | Given <precondition>, when <input/action>, then <expected output> | <path/to/test_file> |

## Technical Details

## Dependencies

## Effort Estimate
- Size: XS/S/M/L/XL
- Hours: N

## Definition of Done
- [ ] Test Case を先行作成し、想定どおりの理由での失敗を確認 (Red)
- [ ] 最小限の実装で全 Test Case が通過 (Green)
- [ ] 全 Test の通過を維持したまま Refactor 実施 (Refactor)
- [ ] Closing Gate 通過 (`conventions.md` → Test Gates。N/A の Task にも適用)
- [ ] コードレビュー完了
```

**Test Cases** は Test 連鎖 (PRD `AC` → Epic `TS` → Task `TC`) の最も具体的な階層。コード作成前の本段階で記述し、実行エージェントが最初に失敗 Test へ変換する。`conventions.md` → Writing Test Cases に従う。Test 可能な振る舞いのない Task は、表を `N/A — <reason>` で置換し、Definition of Done の TDD 項目を N/A とする (`conventions.md` → 例外 参照)。

**Task 保存前の品質基準:**
- Epic の Acceptance Test Matrix の全 `TS-<n>` が、一つ以上の Task の Test Case の `Covers` 列に出現。未網羅の Scenario なし。
- 各 Test Case に具体的な入力と期待出力あり。「正しく動作する」等の曖昧な表現なし。
- `## Test Cases` は空欄不可。Test Case または `N/A — <reason>` を記載。

**Stack delivery** (Epic が `delivery: stack`): 全 Task が一つの Pull Request となるため、各 Task を一回のレビューで完結する規模 (変更行数 400 程度以下) に設定。XL 見積の Task は分割。順序は引き続き `depends_on` のみで決定し、全 Task が単一の直線的 stack を構成。

**採番**: 001.md, 002.md 等の連番。Sync 後に Task は GitHub Issue 番号へ改名されるため、依存関係をファイル名で固定記述せず、`depends_on` 配列を使用。

### After Creating All Tasks

Epic ファイルへ要約を追記:

```markdown
## Tasks Created
- [ ] 001.md - <Title> (parallel: true/false)
- [ ] 002.md - <Title> (parallel: true/false)

Total tasks: N
Parallel tasks: N
Sequential tasks: N
Test cases: N (test scenarios covered: N/N)
Estimated total effort: N hours
```

stack delivery の場合、続けて `bash references/scripts/stack-plan.sh <name> --write` を実行し、Layer 順序を Epic ファイルへ追記:

```markdown
## Stack
1. 001.md - <Title> (base: main)
2. 002.md - <Title> (base: 001)
```

スクリプトが循環依存を報告した場合、続行前に `depends_on` を修正。

**完了後**: 「✅ Epic <name> の Task を N 件作成」と報告し、「GitHub へ push する場合の指示例: <name> の Epic を Sync」と提案。

---

## 依存関係の規則
- `depends_on`: 当該 Task の着手前に完了必須の Task 番号を列挙。
- `parallel: true`: 競合しない他 Task との同時実行が可能。
- `conflicts_with`: 同一ファイルに触れる Task を列挙。これらは並列実行不可。
- 循環依存はエラー。確定前に確認。
