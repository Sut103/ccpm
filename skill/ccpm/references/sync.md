# Sync — Push to GitHub & Track Progress

本 Phase では、ローカルの Epic・Task の GitHub Issue としての反映、進捗のコメントとしての Sync、作業完了時の Issue のクローズを扱う。

---

## Repository Safety Check

**GitHub への全書き込み操作の前に必ず実行:**

```bash
remote_url=$(git remote get-url origin 2>/dev/null || echo "")
if [[ "$remote_url" == *"automazeio/ccpm"* ]]; then
  echo "❌ CCPM テンプレートリポジトリへの Sync は不可。"
  echo "remote を更新: git remote set-url origin https://github.com/YOUR/REPO.git"
  exit 1
fi
REPO=$(echo "$remote_url" | sed 's|.*github.com[:/]||' | sed 's|\.git$||')
```

---

## Epic Sync — Push Epic + Tasks to GitHub

**起動条件**: ローカルの Epic とその Task の GitHub Issue としての反映をユーザーが要望。

### Preflight
- `.claude/epics/<name>/epic.md` の存在を確認。
- 連番 Task ファイルの存在を確認。不在の場合: 「❌ Sync 対象の Task なし。先に Epic を分解。」

### Process

**Step 1 — Epic Issue の作成:**

epic.md から Frontmatter を除去し、次を実行:
```bash
awk 'NR==1 && /^---$/ {fm=1; next} fm && /^---$/ {fm=0; next} !fm' .claude/epics/<name>/epic.md > /tmp/epic-body.md
epic_number=$(gh issue create \
  --repo "$REPO" \
  --title "Epic: <name>" \
  --body-file /tmp/epic-body.md \
  --label "epic,epic:<name>,feature" \
  --json number -q .number)
```

**Step 2 — Task の sub-issue 作成:**

`gh-sub-issue` 拡張の利用可否を確認:
```bash
if gh extension list | grep -q "yahsan2/gh-sub-issue"; then
  use_subissues=true
fi
```

Task 5 件未満: 逐次作成。
Task 5 件以上: 並列の Task エージェントを使用 (1 群 3-4 Task)。

Task ごとに:
```bash
awk 'NR==1 && /^---$/ {fm=1; next} fm && /^---$/ {fm=0; next} !fm' <task_file> > /tmp/task-body.md
task_number=$(gh issue create \
  --repo "$REPO" \
  --title "<task_name>" \
  --body-file /tmp/task-body.md \
  --label "task,epic:<name>" \
  --json number -q .number)
# sub-issue を使用する場合:
# gh sub-issue create --parent $epic_number ...
```

**Step 3 — Task ファイルの改名と参照の更新:**

全 Issue の作成後、`001.md` → `<issue_number>.md` へ改名し、全 `depends_on` / `conflicts_with` 配列を連番ではなく実際の Issue 番号へ更新。

```bash
# 旧→新の対応表を作成後、各 Task ファイルに対し:
# 書き換えるのは Frontmatter 内の depends_on/conflicts_with 行のみ
sed -i.bak -E "/^(depends_on|conflicts_with):/ s/(^|[^0-9])001([^0-9]|$)/\1<new_num_1>\2/g" <file> && rm <file>.bak  # 対応ごとに反復
mv 001.md <new_num>.md
```

**Step 4 — Frontmatter の更新:**
```bash
current_date=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
# epic.md と各 Task ファイルの github: と updated: フィールドを更新
github_url="https://github.com/$REPO/issues/<number>"
# 変更対象は Frontmatter 内の行のみ (conventions.md 参照)
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

**Step 5 — Epic 用 Worktree の作成:**
```bash
git checkout main && git pull origin main
git worktree add ../epic-<name> -b epic/<name>
```

stack delivery では `epic/<name>` ブランチは不在。改名後も Layer 順序が成立することを確認 (`bash references/scripts/stack-plan.sh <name> --check`) し、最下層のブランチ上に Worktree を作成:
```bash
git worktree add ../epic-<name> -b epic/<name>/<bottom_N> main
```

**Step 6 — github-mapping.md の作成:**
```markdown
# GitHub Issue Mapping
Epic: #<N> - https://github.com/<repo>/issues/<N>
Tasks:
- #<N>: <title> - https://github.com/<repo>/issues/<N>
Synced: <datetime>
```

**出力:**
```
✅ Epic <name> を GitHub へ Sync 完了
  Epic: #<N>
  Task: sub-issue N 件
  Worktree: ../epic-<name>
  次の指示例: 「Issue <N> に着手」または「<name> の Epic を開始」
```

---

## Issue Sync — Post Progress to GitHub

**起動条件**: ローカルの開発進捗の GitHub Issue へのコメントとしての Sync をユーザーが要望。

### Preflight
- Issue の存在を確認: `gh issue view <N> --json state`
- `.claude/epics/*/updates/<N>/` と `progress.md` の存在を確認。
- progress.md の `last_sync` を確認。前回 Sync から 5 分未満の場合、続行前に確認。

### Process

`.claude/epics/<epic>/updates/<N>/` (progress.md, notes.md, commits.md) から更新内容を収集。

整形してコメントを投稿:
```bash
gh issue comment <N> --body-file /tmp/update-comment.md
```

コメント形式:
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

投稿後: progress.md の Frontmatter の `last_sync` と、Task ファイルの `updated` を更新。

重複コメント防止のため、ローカルファイルに Sync 標識を追記:
```markdown
<!-- SYNCED: <datetime> -->
```

---

## Submitting a Task (stack delivery)

**起動条件**: `delivery: stack` の Epic の Task が完了。例: 「Issue N を Submit」「Issue N の PR を作成」、または全 Stream の完了。

stack delivery では「Closing an Issue」を本手順が代替。CCPM は Layer を Submit し、PR のマージ時に Issue がクローズ。

### Preflight
- 当該 Task が次に Submit すべき Layer であること: 直下の Task (`position` 基準) が `in-review` または `closed`。
- `../epic-<name>/` の Task ブランチ `epic/<name>/<N>` 上で、`conventions.md` → Test Gates の Layer Gate を実行。不通過の場合: 「❌ #<N> の Submit 不可: <failing or missing test cases>。」 ユーザーの明示的な承認を得た場合に限り続行。
- Worktree に未コミットの変更なし。

### Process

1. Layer ブランチを push: `git push -u origin epic/<name>/<N>`
2. PR 本文を `/tmp/pr-body.md` に記述:
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
3. PR を作成 (`conventions.md` → Pull Request Operations 参照)。base は直下 Layer のブランチ、最下層の場合は `main`:
```bash
pr_url=$(gh pr create --repo "$REPO" --base <base_branch> --head epic/<name>/<N> \
  --title "<task_name>" --body-file /tmp/pr-body.md)
```
4. 第二 Layer 以降は、可能な限り stack を連結: Submit 済み全 Layer のブランチを下層から上層の順に指定して `gh stack link` を再実行、または stacks REST エンドポイントを使用 (最初の二つの PR から stack を作成し、以降の各 PR について `POST repos/<owner>/<repo>/stacks/<stack_number>/add`)。いずれも利用不可の場合、PR は未連結のまま。
5. Task ファイルに `status: in-review`、`pr: <pr_url>`、`updated: <now>` を設定。
6. Epic Issue の当該 Task 行に PR を追記:
```bash
gh issue view <epic_N> --json body -q .body > /tmp/epic-body.md
sed -i "s|^- \[ \] #<N>\(.*\)$|- [ ] #<N>\1 (PR <pr_url>)|" /tmp/epic-body.md
gh issue edit <epic_N> --body-file /tmp/epic-body.md
```

**出力:**
```
✅ #<N> を Layer <position>/<total> として Submit: <pr_url>
  次の Layer: #<next_N> — 「Issue <next_N> に着手」
```

Submit 済み Layer に追加の変更が必要な場合、`conventions.md` → Changing a Lower Layer に従う。

---

## Closing an Issue

**起動条件**: ユーザーが Task を完了と判定。merge delivery 専用。stack delivery の場合は Submitting a Task 参照。

### Preflight
- Epic Worktree (`../epic-<name>/`) で `conventions.md` → Test Gates の Closing Gate を実行。不通過の場合: 「❌ #<N> のクローズ不可: <failing or missing test cases>。」 ユーザーの明示的な承認を得た場合に限り続行。

### Process

1. ローカルの Task ファイル (`.claude/epics/*/<N>.md`) を特定。
2. Frontmatter を更新: `status: closed`、`updated: <now>`。
3. 完了コメントを投稿:
```bash
echo "✅ Task 完了 — 全 Acceptance Criteria 充足、全 Test Case 通過。" | gh issue comment <N> --body-file -
# Closing Gate をユーザー承認により通過した場合は次を投稿:
# "✅ ユーザー承認により Task をクローズ — 未通過: <failing or missing test cases>"
gh issue close <N>
```
4. Epic Issue 本文の当該 Task にチェックを付与:
```bash
gh issue view <epic_N> --json body -q .body > /tmp/epic-body.md
sed -i "s/- \[ \] #<N>/- [x] #<N>/" /tmp/epic-body.md
gh issue edit <epic_N> --body-file /tmp/epic-body.md
```
5. Epic の進捗を再計算・更新: `progress = closed_tasks / total_tasks * 100`

---

## Merging an Epic

**起動条件**: 完了した Epic の main へのマージをユーザーが要望。

stack delivery では CCPM はマージしない。全 Task の PR のマージをもって Epic 完了。下記 Process の代わりに次を実施:
1. 各 Task Issue と各 Task PR の状態を取得 (`conventions.md` → Pull Request Operations 参照)。open の Issue またはマージ未完了の PR がある場合、一覧を提示して中断。
2. 全 Task を `status: closed` に設定し、Epic Issue 本文でチェックを付与、Epic を `progress: 100%` に設定。
3. 後始末とアーカイブ:
```bash
git worktree remove ../epic-<name>
for b in $(git branch --list "epic/<name>/*" --format='%(refname:short)'); do
  git branch -D "$b"                          # PR はマージ済み (手順 1)。squash マージでは git 上は未マージ扱いのため -D
  git push origin --delete "$b" 2>/dev/null   # GitHub 側で削除済みの可能性あり
done
mkdir -p .claude/epics/archived/
mv .claude/epics/<name> .claude/epics/archived/
gh issue close <epic_N> -c "Epic completed: all task PRs merged"
```
4. epic.md の Frontmatter を更新: `status: completed`。

merge delivery の場合:

### Preflight
- Worktree `../epic-<name>` の存在を確認。
- Worktree 内の未コミットの変更を確認。変更が残存する場合は中断。
- 未完了の Task Issue が残存する場合は警告。
- Worktree で `conventions.md` → Test Gates の Merging Gate を実行。不通過の場合、ユーザーの明示的な承認がない限りマージを中断。

### Process

```bash
# Worktree で: 全テストスイートを実行 (Epic の Test Strategy 記載のコマンド)
cd ../epic-<name>
# 例: npm test / pytest / cargo test / go test — Gate 不通過かつユーザー未承認の場合はここで中断

# main リポジトリで:
git checkout main && git pull origin main
git merge epic/<name> --no-ff -m "Merge epic: <name>"
git push origin main

# 後始末
git worktree remove ../epic-<name>
git branch -d epic/<name>
git push origin --delete epic/<name>

# アーカイブ
mkdir -p .claude/epics/archived/
mv .claude/epics/<name> .claude/epics/archived/

# GitHub Issue のクローズ
epic_issue=$(grep 'github:' .claude/epics/archived/<name>/epic.md | grep -oE '[0-9]+$')
gh issue close $epic_issue -c "Epic completed and merged to main"
```

epic.md の Frontmatter を更新: `status: completed`。

---

## Reporting a Bug Against a Completed Issue

**起動条件**: 完了済みまたは進行中の Issue の検証中にユーザーがバグを発見。例: 「Issue 42 でバグを発見」「Issue 42 の検証中にメール検証の不具合が判明」。

手順は自動で完結させる。元 Issue の文脈を保持したまま、関連付けたバグ Task を作成。

### Process

**Step 1 — 文脈把握のため元 Issue を読込:**
```bash
gh issue view <original_N> --json title,body,labels
```
ローカルの Task ファイルが存在する場合はそれも読込: `.claude/epics/*/<original_N>.md`

**Step 2 — ローカルのバグ Task ファイルの作成:**

修正は Test 先行。TC-1 はバグを再現する回帰 Test。修正前に作成して失敗を確認 (Red) し、修正によって通過させる (Green)。

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
- [ ] 回帰 Test TC-1 がバグを再現し、修正前に失敗
- [ ] バグ修正済み — TC-1 が通過
- [ ] 元 Issue #<original_N> の振る舞いに影響なし — その Test Case が引き続き通過

## Effort Estimate
- Size: XS/S
```

保存先: `.claude/epics/<same_epic_as_original>/bug-<original_N>-<slug>.md`

**Step 3 — 関連付けた GitHub Issue の作成:**
```bash
gh issue create \
  --repo "$REPO" \
  --title "Bug: <short description>" \
  --body "$(cat /tmp/bug-body.md)" \
  --label "bug,epic:<epic_name>" \
  --json number -q .number
```

GitHub の自動リンクのため、Issue 本文の冒頭に `Fixes / follow-up to #<original_N>` を記載。

**Step 4 — ローカルファイルの更新**。GitHub Issue 番号を反映し、`<new_N>.md` へ改名。

stack delivery の場合、バグ Task は新たな最上位 Layer となる: `bash references/scripts/stack-plan.sh <epic_name> --write` を実行。

**出力:**
```
✅ バグ Issue 作成完了: #<new_N> — "Bug: <short description>"
  関連元: #<original_N>
  Epic: <epic_name>

修正開始の指示例: 「Issue <new_N> に着手」
```
