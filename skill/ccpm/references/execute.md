# Execute — 並列エージェントによる構築開始

本 Phase では、GitHub Issue を並列 Stream の観点で分析し、それを実行するエージェントを起動する。

---

## Issue Analysis

**起動条件**: 着手前に Issue の作業の並列化方法の把握をユーザーが要望。

### Preflight
- ローカルの Task ファイルを特定: 先に `.claude/epics/*/<N>.md` を確認し、次に Frontmatter 内の `github:.*issues/<N>` を検索。
- 不在の場合: 「❌ Issue #<N> に対応するローカル Task なし。先に Sync を実行。」

### Process

Issue 詳細を取得: `gh issue view <N> --json title,body,labels`

ローカルの Task ファイルを全文読了。次の観点で独立した Stream を特定:
- 作成・変更対象のファイル
- 競合なしに同時進行可能な変更
- 変更間の依存関係
- 各 Stream の振る舞いが担う Task ファイル内の Test Case (`TC-<n>`)

**代表的な Stream 構成:**
- Database Layer: schema、migration、model
- Service Layer: business logic、data access
- API Layer: endpoint、validation、middleware
- UI Layer: component、ページ、スタイル

Test 専用の Stream は設けない。各 Stream が自身の構築する振る舞いの Test Case を担い、先行作成する (`conventions.md` → TDD & Test Traceability 参照)。Task ファイル内の全 `TC-<n>` を、それぞれ厳密に一つの Stream へ割当:
- 複数 Stream の成果を要する Test Case は、依存連鎖で最後に完了する Stream へ割当。先行 Stream へ割り当てた場合、後続 Stream の完了まで当該 Test を通過できず、deadlock が発生。
- 振る舞いを追加する Stream は、全て一つ以上の Test Case を担う。先行 Stream に Test Case が残らない場合、その担当部分の unit 水準の Test Case を Task の `## Test Cases` へ追加 (Task のみの変更。`conventions.md` → Changing Test Cases 参照) するか、当該 Stream を Test Case を担う Stream へ統合。観測可能な振る舞いを追加しない Stream は、代わりに `N/A — <reason>` と記載 (`conventions.md` → 例外 参照)。
- Test ファイルを共有する Test Case は同一 Stream へ割当。そうでなければファイルを分割。各 Stream の Test ファイルを **Files** に列挙。
- 共有の Test fixture や helper は後述の共有ファイル規則に従い、指定の一 Stream が担う。

`.claude/epics/<epic_name>/<N>-analysis.md` を作成:

```markdown
---
issue: <N>
title: <title>
analyzed: <run: date -u +"%Y-%m-%dT%H:%M:%SZ">
estimated_hours: <total>
parallelization_factor: <1.0-5.0>
---

# Parallel Work Analysis: Issue #<N>

## Overview

## Parallel Streams

### Stream A: <Name>
**Scope**: 
**Files**: 
**Test Cases**: TC-1, TC-2
**Can Start**: immediately
**Estimated Hours**: 
**Dependencies**: none

### Stream B: <Name>
**Scope**: 
**Files**: 
**Test Cases**: TC-3
**Can Start**: after Stream A
**Dependencies**: Stream A

## Coordination Points
### Shared Files
### Sequential Requirements

## Conflict Risk Assessment

## Parallelization Strategy

## Expected Timeline
- With parallel execution: <max_stream_hours>h wall time
- Without: <sum_all_hours>h
- Efficiency gain: <pct>%
```

**出力**: 「✅ Issue #<N> の分析完了 — 並列 Stream を N 件特定。着手する場合の指示例: Issue <N> を開始」

---

## Starting an Issue

**起動条件**: 特定の GitHub Issue への着手をユーザーが要望。

### Preflight
1. Issue の存在と open 状態を確認: `gh issue view <N> --json state,title,labels,body`
2. ローカルの Task ファイルを特定 (前述と同様)。
3. 分析ファイル `.claude/epics/*/<N>-analysis.md` の有無を確認。不在の場合は先に分析を実施 (または分析と開始を連続実行)。
4. Epic Worktree の存在を確認: `git worktree list | grep "epic-<name>"`。不在の場合: 「❌ Worktree なし。先に Epic を Sync。」
5. stack delivery 専用: 直下の Task (`position` 基準) が `in-review` または `closed`、もしくは当該 Task が最下層であること。それ以外の場合: 「❌ #<N> は Layer #<below_N> の Submit 待ち。」 条件を満たす場合、Worktree を当該 Layer の branch へ切替:
   ```bash
   cd ../epic-<name>
   git checkout epic/<name>/<N> 2>/dev/null || git checkout -b epic/<name>/<N> epic/<name>/<below_N>
   ```
   最下層の branch は Epic の Sync 時に作成済み。

### Process

**Step 1 — 分析の読込**。即時着手可能な Stream と依存関係を持つ Stream を判別。

**Step 2 — 進捗管理の準備:**
```bash
mkdir -p .claude/epics/<epic>/updates/<N>
current_date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
```

Stream ごとに `.claude/epics/<epic>/updates/<N>/stream-<X>.md` を作成:
```markdown
---
issue: <N>
stream: <stream_name>
started: <datetime>
status: in_progress
---
## Scope
## Progress
- Starting implementation
```

**Step 3 — 並列エージェントの起動**。即時着手可能な各 Stream が対象:

```yaml
Task:
  description: "Issue #<N> Stream <X>"
  subagent_type: "general-purpose"
  prompt: |
    担当: Issue #<N>。作業場所は Epic Worktree ../epic-<name>/
    stack delivery 専用 — 担当 branch: epic/<name>/<N>。branch 切替は厳禁。
    
    担当 Stream: <stream_name>
    担当範囲 — 変更対象ファイル: <file_patterns>
    担当 Test Case: <TC IDs>
    作業内容: <stream_description>
    
    指示:
    1. Task 全文を読込: .claude/epics/<epic>/<N>.md
    2. 分析を読込: .claude/epics/<epic>/<N>-analysis.md
    3. TDD 規則を読込: <skill_path>/references/conventions.md → TDD & Test Traceability
    4. 作業は割当ファイルに限定
    5. 上記規則に従い Test 先行で作業:
       a. Red: 担当 Test Case の Test を "[#<N> TC-<n>]" tag 付きで作成・実行し、
          想定どおりの理由での失敗を確認 (Test が compile 不能な場合は最小限の stub を
          同時に commit)。commit: "Issue #<N>: add failing tests for <TC IDs>"
       b. Green: Test を通過させる最小限のコードを作成。
          commit: "Issue #<N>: <specific change>"
       c. Refactor: 全 Test の通過を維持したまま整理。変更があれば commit。
       担当 Stream の Test Cases が "N/A — <reason>" の場合、Test 関連手順 (Red, Green,
       Refactor) を省略し、記載の作業を実施後、手順 6 へ進む。
    6. プロジェクトの全 test suite を実行 (<test command from the epic's Test Strategy>)。
       自身の変更で既存の通過 Test が失敗した場合は自身の変更を修正。他の稼働中 Stream や
       他の未完了 Task の失敗 Test は想定内のため放置。他者の変更により test suite が
       build 不能の場合は、待機して pull。自身では修正しない。
    7. 進捗を更新: .claude/epics/<epic>/updates/<N>/stream-<X>.md
    8. 担当範囲外のファイル変更が必要な場合、進捗ファイルに記録して待機
    9. git 操作での --force 使用は厳禁
    
    status: completed は、担当 Test Case が全て通過し、既存の通過 Test に失敗がない場合に限り設定。
```

未充足の依存関係を持つ Stream は待機列へ入れ、依存先の完了に応じて起動。

**Step 4 — GitHub での担当設定:**
```bash
gh issue edit <N> --add-assignee @me --add-label "in-progress"
```

**Step 5 — 実行状態ファイルの作成**。配置先は `.claude/epics/<epic>/updates/<N>/execution.md`:
```markdown
## Active Streams
- Stream A: <name> — Started <time>
- Stream B: <name> — Started <time>

## Queued
- Stream C: <name> — Waiting on Stream A

## Completed
(none yet)
```

**出力:**
```
✅ Issue #<N> の作業開始

エージェントを N 件起動:
  Stream A: <name> ✓ 開始
  Stream B: <name> ✓ 開始
  Stream C: <name> ⏸ 待機 (A に依存)

監視: .claude/epics/<epic>/updates/<N>/ で進捗確認
更新の Sync: 「Issue <N> を Sync」
```

stack delivery の場合、全 Stream の完了後に Task を Submit (`sync.md` → Submitting a Task)。

---

## Starting a Full Epic

**起動条件**: Epic 内の着手可能な全 Issue に対する並列エージェントの一括起動をユーザーが要望。

### Preflight
- `.claude/epics/<name>/epic.md` の存在と `github:` field の有無 (Sync 済みであること) を確認。
- 未 commit の変更を確認: `git status --porcelain`。変更が残存する場合は中断。
- Epic branch の存在を確認: `git branch -a | grep "epic/<name>"`

### Process

**Step 1 — 全 Task ファイルの読込**。対象は `.claude/epics/<name>/`。Frontmatter から `status`、`depends_on`、`parallel` を解析。

**Step 2 — Task の分類:**
- Ready: status=open、未充足の depends_on なし
- Blocked: 未充足の depends_on あり
- In Progress: 実行ファイルが既存
- Complete: status=closed

**Step 3 — 着手可能 Task の分析**。分析ファイルが未作成のものが対象 (Issue Analysis をその場で実施)。

**Step 4 — エージェントの起動**。着手可能な全 Task について、前述の Issue 単位の起動手順と同様に実施。stack delivery では、着手可能な Task は常に一件のみ (`open` のままの最下位 Layer)。

**Step 5 — 作成・更新**。`.claude/epics/<name>/execution-status.md` に稼働中の全エージェントと待機中の Issue を記録。

**Step 6 — エージェント完了時**、阻害中だった Issue の解除を確認し、該当エージェントを起動。stack delivery では、完了した Task を先に Submit。その Submit により次の Layer の阻害が解除。

---

## エージェント協調規則

複数エージェントが同一 Worktree で同時に作業する場合:

- 各エージェントは割当 Stream の範囲内のファイルのみ操作。
- エージェントは `Issue #<N>: <description>` 形式で頻繁に commit。
- 共有ファイルの変更前に `git status <file>` を確認。他エージェントが変更中の場合、待機して先に pull。
- エージェント間の同期は commit 経由: 新規ファイル作業の開始前に `git pull --rebase origin epic/<name>`。stack delivery では Layer branch は Submit までローカルのみに存在するため、pull を省略。
- 競合の自動解決は厳禁。エージェントは報告して一時停止。
- Stream の完了条件は、自身の Test Case が全て通過し、既存の通過 Test に失敗がないこと。他の稼働中 Stream や未完了 Task の Red Test は作業中のため想定内であり、放置。Test を通過させる目的での Test の弱化・削除は厳禁。
- `--force` flag は一切使用禁止。

調整を要しがちな共有ファイル (型定義、設定、package.json) は指定の一 Stream が担当し、他 Stream はその commit 後に pull。
