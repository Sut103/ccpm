# 規約 — ファイル形式・パス・規則

全 Phase 共通。ファイル操作の前に必読。

---

## ディレクトリ構成

```
.claude/
├── prds/
│   └── <feature-name>.md          # PRD
├── epics/
│   ├── <feature-name>/
│   │   ├── epic.md                # 技術 Epic
│   │   ├── <N>.md                 # Task ファイル (Sync 後は GitHub Issue 番号で命名)
│   │   ├── <N>-analysis.md        # 並列 Stream 分析
│   │   ├── github-mapping.md      # Issue 番号 → URL の対応表
│   │   ├── execution-status.md    # 稼働中エージェントの管理表
│   │   └── updates/
│   │       └── <issue_N>/
│   │           ├── stream-A.md    # エージェント別進捗
│   │           ├── progress.md    # Issue 全体の進捗
│   │           └── execution.md  # 実行状態
│   └── archived/
│       └── <feature-name>/        # 完了済み Epic
└── context/                       # プロジェクト文脈文書 (別系統)
```

---

## Frontmatter スキーマ

### PRD (.claude/prds/<name>.md)
```yaml
---
name: <feature-name>        # kebab-case、ファイル名と一致
description: <one-liner>    # 一覧・要約に使用
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
progress: 0%                # Task のクローズ時に再計算
prd: .claude/prds/<name>.md
github: https://github.com/<owner>/<repo>/issues/<N>  # Sync 時に設定
delivery: merge             # merge | stack (Delivery Modes 参照)。未指定は merge
---
```

### Task (.claude/epics/<name>/<N>.md)
```yaml
---
name: <Task Title>
status: open | in-progress | in-review | closed   # in-review: stack delivery 専用
created: <ISO 8601>
updated: <ISO 8601>
github: https://github.com/<owner>/<repo>/issues/<N>  # Sync 時に設定
depends_on: []              # 完了を待つべき Issue 番号
parallel: true              # 競合しない Task との同時実行可否
conflicts_with: []          # 同一ファイルに触れる Issue 番号
position: 1                 # stack delivery 専用: stack 内の Layer、1 = 最下層 (stack-plan.sh が設定)
pr: https://github.com/<owner>/<repo>/pull/<N>  # stack delivery 専用: Submit 時に設定
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

開発は既定で Test 駆動。Acceptance Criteria は PRD → Epic → Task と作業の進行に応じて段階的に詳細化し、全 Test Case は自身が証明する要件まで追跡可能とする。

### ID 体系

| ID | 定義箇所 | セクション | 内容 |
|---|---|---|---|
| `US-<n>` | PRD | `## User Stories` | User Story |
| `AC-<n>` | PRD | `## Acceptance Criteria` | Story の完了を証明する観測可能な振る舞い (Given/When/Then、実装詳細を含まない) |
| `TS-<n>` | Epic | `## Test Strategy` → `### Acceptance Test Matrix` | 一つの AC を選定した水準 (unit / integration / e2e) で証明する Test Scenario |
| `TC-<n>` | Task | `## Test Cases` | 具体的な Test: 前提条件、入力、期待出力、Test ファイル位置 |

ID はファイル単位で採番 (PRD 内で `AC-1`, `AC-2`, ...、各 Task 内で `TC-1`, `TC-2`, ...) し、削除後も再利用しない。各 TC は対象の TS (または後述の例外) を、各 TS は対応する AC を、各 AC は対応する US を明記する。

### Red → Green → Refactor

Task の実装は次の周期に従う。

1. **Red** — 本番コードより先に、Task の Test Case に対する Test を作成。実行し、想定どおりの理由 (Assertion 失敗または振る舞いの欠如) で失敗することを確認。構文エラー、import 不良、Test 準備の不備による失敗は Red に該当せず、先に Test を修正。対象コードが未存在のため Test のコンパイルや import が不可能な場合、最小限の stub (シグネチャのみ、本体は "not implemented" を送出) を先に追加して Test と共にコミットし、Worktree 内の他者に対してもテストスイートのビルドを維持する。stub は Red の準備であり、本番コードではない。
2. **Green** — 失敗中の Test を通過させる最小限の本番コードを作成。Test が要求しない振る舞いの追加は禁止。振る舞いを追加する変更は全て Test Case に基づく。
3. **Refactor** — 全 Test の通過を維持したまま、コードと Test を整理。

各段階でコミット: `Issue #<N>: add failing tests for TC-1..TC-3`、`Issue #<N>: <specific change>`、`Issue #<N>: refactor <area>`。Red のコミットは「コミット前に Test を実行」系規則の意図的な例外。pre-commit hook が拒否する場合、hook を回避せず、失敗 Test を Green の変更と同一コミットとする。Test を通過させる目的での Test の弱化・削除は厳禁。

### Writing Test Cases

- Given / When / Then を使用。
- 具体値を使用: `then the total is correct` ではなく `Given a cart with 2 items at $10, when a 10% coupon is applied, then the total is $18.00`。
- 一 Test Case につき一つの振る舞い。正常系のみならず、AC が含意する異常系・境界条件 (不正入力、空状態、上限) も網羅。
- `Test location` には、プロジェクト既存の Test 配置に従い予定の Test ファイルを記入。これは計画であって記録ではなく、Test 作成後の更新は不要。
- 表のセル内の `|` は `\|` へエスケープ。

### Tests Are the Record

`## Test Cases` の表は、コード作成前に記述する仕様。Test 作成後は、Test コードと Test 実行結果が正本。Test Case 単位の状態 (通過、失敗、未作成) をファイルや Issue コメントへ記録することは禁止。状態確認は Test 実行による。

Test Case とコード上の Test との対応を維持するため、Test 名に `[#<N> TC-<n>]` タグを付与。例: `it("[#1234 TC-2] rejects a duplicate email")`。Test 名にタグを含められない場合 (Go や pytest の関数名等)、Test の直上行のコメントに記載。角括弧により `TC-1` と `TC-10` の誤照合を防止し、`grep -rnF "[#1234 TC-2]"` で該当 Test を検索可能。

### Changing Test Cases

上位階層の更新は、変更がその階層の粒度に及ぶ場合に限る。

| 変更内容 | 更新対象 |
|---|---|
| 具体値の変更、TC の分割・追加 | Task の `## Test Cases` のみ |
| Scenario の証明対象、Test 水準、Scenario を有する AC の範囲 | Epic の `### Acceptance Test Matrix` も更新 |
| Acceptance Criterion の意味 | PRD の `## Acceptance Criteria` も更新し、下位へ反映 |

TS をどの Task が担うかは、Task の `Covers` 列のみに記録。

### Test Gates

Closing Gate (Issue のクローズ) と Merging Gate (Epic のマージ) は、いずれも Epic Worktree でプロジェクトの全テストスイート (Epic の `### Test Levels & Tooling` 記載のコマンド) を実行する。通過条件は以下。

- 対象 Task (クローズ時) または全 Task (マージ時) の全 `TC-<n>` に、`[#<N> TC-<n>]` タグで特定可能な Test が存在し、かつ通過。
- 他の Test に失敗がない。ただし `### Test Levels & Tooling` に既知の失敗 (baseline failure) として記載の Test と、クローズ時における Epic 内の他の未完了 Task に属する Test を除く。

Test Cases が `N/A — <reason>` の Task は、第二条件のみ適用。Gate 不通過の場合、失敗内容と原因をユーザーへ報告し、明示的な承認を得た場合に限り続行。

stack delivery では、**Layer Gate** が Closing Gate を代替し、Merging Gate は存在しない。Task の Submit 前に、Epic Worktree 上の当該 Task の Layer ブランチで実行。通過条件は、Task の全 `TC-<n>` に通過する Test が存在すること (前述と同様) と、既知の失敗以外に失敗 Test がないこと。他の未完了 Task の Test も除外しない。上位 Layer の Task は当該ブランチに含まれず、下位 Layer の Task は全て当該ブランチに含まれるため。

### 例外

TDD は既定であって絶対ではない。

- **観測可能な振る舞いなし**: Test で観測可能な振る舞いを追加しない変更 (文書、検証対象のない設定、期間限定の spike 等) は Test Case 不要。Task の場合、`## Test Cases` に `N/A — <reason>` と記載し、Definition of Done の TDD 項目を N/A とする。Stream の場合、分析内の当該 Stream の **Test Cases** 欄に記載。セクションや欄の省略、理由なしの N/A は不可。spike から本番コードが生じた場合、そのコードは独自の Test Case を持つ後続 Task へ移管。
- **Test が既に通過** (Refactor 用の characterization test、または先行 Task で実装済みの振る舞い): Red の代わりに当該 Test をコミット。コミットメッセージには "failing" の代わりに理由を記載。例: `Issue #<N>: add tests for TC-4 (already passing: characterizes current behavior)`。
- **PRD の Acceptance Criterion なし** (環境構築、基盤、Refactoring): Task の `## Acceptance Criteria` に `AC: n/a (<reason>)`、その Test Case の `Covers` 列に `n/a (<reason>)` と記載。
- **バグ修正**: 回帰 Test の `Covers` は TS ではなく `Regression #<original_N>`。

---

## 日時規則

現在日時は必ずシステムから実値を取得。プレースホルダー文字列は使用禁止。
```bash
date -u +"%Y-%m-%dT%H:%M:%SZ"
```

---

## Frontmatter 更新手順

既存ファイルの Frontmatter の単一フィールド更新 (Frontmatter 内の行のみ変更):
```bash
awk -v k="<field>" -v v="<value>" '
  NR==1 && /^---$/ {fm=1; print; next}
  fm && /^---$/    {fm=0}
  fm && index($0, k":")==1 {print k": "v; next}
  {print}' <file> > <file>.tmp && mv <file>.tmp <file>
```

GitHub 用の本文取得のための Frontmatter 除去 (本文中の `---` 行は保持):
```bash
awk 'NR==1 && /^---$/ {fm=1; next} fm && /^---$/ {fm=0; next} !fm' <file> > /tmp/body.md
```

`sed '1,/^---$/d; 1,/^---$/d'` および `sed "/^<field>:/c\\..."` は使用禁止。GNU sed では前者が本文まで削除し (次の `---` まで、または全文)、後者が本文中の一致行まで書き換えるため。

---

## GitHub 操作

### リポジトリ安全確認 (全書き込み操作の前に実行)
```bash
remote_url=$(git remote get-url origin 2>/dev/null || echo "")
if [[ "$remote_url" == *"automazeio/ccpm"* ]]; then
  echo "❌ CCPM テンプレートリポジトリへの書き込みは不可。"
  echo "remote を更新: git remote set-url origin https://github.com/YOUR/REPO.git"
  exit 1
fi
REPO=$(echo "$remote_url" | sed 's|.*github.com[:/]||' | sed 's|\.git$||')
```

### 認証
認証の事前確認は不要。`gh` コマンドを実行し、失敗時に対処。
```bash
gh <command> || echo "❌ GitHub CLI 失敗。実行: gh auth login"
```

### Getting Issue Numbers
```bash
# Task ファイルの github フィールドから取得:
grep 'github:' <file> | grep -oE '[0-9]+$'
```

---

## Delivery Modes

完了した作業の main への反映方法は、Epic の `delivery` フィールドで決定。Epic 作成時に選択し、Epic の Sync 後は変更不可。

| | `merge` (既定) | `stack` |
|---|---|---|
| ブランチ | Epic ごとに一本: `epic/<name>` | Task (Layer) ごとに一本: `epic/<name>/<N>`。`epic/<name>` ブランチは不在 |
| Pull Request | なし。Epic ブランチを main へマージ | Task ごとに一つの PR、単一の直線的 stack として連結 |
| Task の順序 | `depends_on` に従う。`parallel` の Task は同時実行 | 全 Task が単一 stack の一 Layer、`position` 順。Task は逐次実行、Task 内の Stream は引き続き並列実行 |
| Task の完了 | Closing an Issue で完了 | PR の Submit 時に `in-review`。PR マージ時に Issue がクローズ (`Closes #<N>`) |
| Gate | Task ごとに Closing Gate、Epic ごとに Merging Gate | Task ごとに Layer Gate (Test Gates 参照) |
| Epic の終了 | main へ `git merge --no-ff` | 全 Task の Issue のクローズを確認し、後始末とアーカイブ。CCPM は PR をマージしない |

### Stack Layout

- `bash references/scripts/stack-plan.sh <name>` で stack を表示。`--write` で各 Task の `position` を保存、`--check` で保存済み position と計画の不一致時に失敗。
- 順序: `position` を持つ Task はその値を維持。その他は `depends_on` 順、Task 番号の小さい順で上に積む。循環依存、または依存先が依存元より下位にない場合はエラー。
- `parallel` と `conflicts_with` は順序に影響しない。全 Layer が逐次。
- Task の着手条件は、直下の Task が `in-review` または `closed` であること。最下層は即時着手可。
- Layer `<N>` はブランチ `epic/<name>/<N>` に配置。PR の base は直下 Layer のブランチ、最下層の場合は main。

### Pull Request Operations

`gh` と GitHub MCP サーバーのうち、ハーネスで利用可能な方を使用。ブランチ、rebase、push には常に Git 本体が必要。

| 操作 | gh | GitHub MCP |
|---|---|---|
| PR 作成 / base 変更 | `gh pr create --base <base> --head <branch>` / `gh pr edit <N> --base <base>` | `create_pull_request` / `update_pull_request` |
| PR を GitHub stack として連結 | `gh stack link <branches...>` (gh-stack 拡張) または `gh api -X POST repos/<owner>/<repo>/stacks -H "X-GitHub-Api-Version: 2026-03-10" -F "pull_requests[]=<N1>" -F "pull_requests[]=<N2>" ...` (下層から上層の順) | 該当ツールなし: PR は未連結のまま |
| Issue の状態取得 | `gh issue view <N> --json state` | `issue_read` |
| PR の状態取得 | `gh pr view <N> --json state` | `pull_request_read` |

連結は任意。未連結でも base が連鎖する PR は各 Layer 固有の差分を表示。欠落するのは GitHub の stack 機能 (stack 表示、複数 Layer の一括マージ、マージ後の上位 Layer の rebase) のみ。

### Changing a Lower Layer

Submit 済み Layer に変更が必要な場合 (上位 Layer の構築中に発見したバグ、または PR へのフィードバック):

1. 当該 Layer のブランチに修正をコミット。通常どおり Test を先行。
2. 上位 Layer を修正ブランチ上へ rebase: `git rebase --update-refs <fixed-branch> <top-branch>` (Git 2.38 以降。中間の Layer ブランチも移動)、または gh-stack 拡張の `gh stack rebase --upstack`。
3. 修正 Layer より上位の全 Layer で Layer Gate を実行。
4. 書き換えた各ブランチを `git push --force-with-lease origin <branch>` で push。

---

## Git / Worktree Conventions

- Epic ごとに一本のブランチ: `epic/<name>` (stack delivery では Layer ごとに一本。Delivery Modes 参照)
- Worktree の配置先は `../epic-<name>/` (プロジェクトルートと同階層)
- ブランチは必ず最新の main から作成:
  ```bash
  git checkout main && git pull origin main
  git worktree add ../epic-<name> -b epic/<name>
  ```
- Epic 内のコミット形式: `Issue #<N>: <description>`
- 全 git 操作で `--force` は使用禁止。例外は stack delivery における Epic 自身の Layer ブランチに限り、rebase 後の `git push --force-with-lease` (Changing a Lower Layer 参照) と、Layer の PR マージ後の `git branch -D` (`sync.md` → Merging an Epic 参照)

---

## 命名規約

- 機能名: kebab-case、小文字、英字・数字・ハイフンのみ、先頭は英字
- Sync 前の Task ファイル: `001.md`, `002.md`, ... (連番)
- Sync 後の Task ファイル: GitHub Issue 番号へ改名 (例: `1234.md`)
- Sync 時に付与するラベル: `epic`, `epic:<name>`, `feature` (Epic)、`task`, `epic:<name>` (Task)

---

## Epic Progress Calculation

```bash
total=$(ls .claude/epics/<name>/[0-9]*.md 2>/dev/null | wc -l)
closed=$(grep -l '^status: closed' .claude/epics/<name>/[0-9]*.md 2>/dev/null | wc -l)
progress=$((closed * 100 / total))
```

Task のクローズ時に Epic の Frontmatter を更新。
