# Track — 現況把握

追跡操作は、速度と一貫性のため bash スクリプトを直接使用。LLM による処理は不要で、スクリプトを実行して出力を提示するのみ。

---

## Script-First Rule

全追跡操作に対応する bash スクリプトあり。スクリプトを実行し、出力を手作業で再構成しない。

スクリプトは本スキル内の `references/scripts/` に配置。ただし実行は **プロジェクトルート** (`.claude/` の所在地) から行う。実行方法:

```bash
bash <skill_path>/references/scripts/<script>.sh [args]
```

ccpm をプロジェクト内に導入済みの場合:
```bash
bash ccpm/scripts/pm/<script>.sh [args]
```

---

## プロジェクト状況

**起動語**: 「状況は」「プロジェクトの状況」「概要」 / "what's our status", "project status", "overview"

```bash
bash references/scripts/status.sh
```

表示内容: 進行中の Epic、未完了 Issue 数、直近の活動。

---

## Standup Report

**起動語**: 「Standup」「日次 Standup」「昨日の作業」「朝の報告」 / "standup", "daily standup", "what did we do", "morning update"

```bash
bash references/scripts/standup.sh
```

表示内容: 前日の完了事項、当日の進行中事項、阻害要因。

---

## List Epics

**起動語**: 「Epic 一覧」「Epic を表示」「既存の Epic」 / "list epics", "show epics", "what epics do we have"

```bash
bash references/scripts/epic-list.sh
```

---

## Show Epic Details

**起動語**: 「<name> の Epic を表示」「<name> の Epic の詳細」 / "show the <name> epic", "epic details for <name>"

```bash
bash references/scripts/epic-show.sh <name>
```

---

## Epic Status

**起動語**: 「<name> の Epic の状況」「<name> の進捗度」 / "status of the <name> epic", "how far along is <name>"

```bash
bash references/scripts/epic-status.sh <name>
```

表示内容: Task 完了状況の内訳、稼働中エージェント、阻害中の Issue。

---

## List PRDs

**起動語**: 「PRD 一覧」「既存の PRD」「Backlog を表示」 / "list PRDs", "what PRDs do we have", "show backlog"

```bash
bash references/scripts/prd-list.sh
```

---

## PRD Status

**起動語**: 「PRD の状況」「Epic 化済みの PRD」「Backlog の内容」 / "PRD status", "which PRDs are parsed", "what's in backlog"

```bash
bash references/scripts/prd-status.sh
```

---

## 検索

**起動語**: 「<query> を検索」「<topic> 関連の Issue を検索」「<term> を探索」 / "search for <query>", "find issues about <topic>", "look for <term>"

```bash
bash references/scripts/search.sh "<query>"
```

ローカルの Task ファイル、PRD、Epic を対象に検索語との一致を探索。

---

## 進行中の作業

**起動語**: 「進行中の作業」「現在の作業内容」「稼働中の作業」 / "what's in progress", "what are we working on", "active work"

```bash
bash references/scripts/in-progress.sh
```

---

## 次の作業

**起動語**: 「次の作業」「次は何をすべきか」「次の優先事項」 / "what should I work on next", "what's next", "next priority"

```bash
bash references/scripts/next.sh
```

阻害する依存関係のない、優先度最上位の未完了 Task を表示。

---

## 阻害中の作業

**起動語**: 「阻害中の作業」「阻害要因の有無」「停滞中の作業」 / "what's blocked", "any blockers", "what can't we move on"

```bash
bash references/scripts/blocked.sh
```

---

## プロジェクト状態の検証

**起動語**: 「検証」「プロジェクト状態の確認」「整合性の確認」 / "validate", "check project state", "is everything consistent"

```bash
bash references/scripts/validate.sh
```

確認項目: Frontmatter の整合性、孤立ファイル、GitHub リンクの欠落、依存関係の健全性。

---

## Stack Layer Order

**起動語**: 「<name> の stack を表示」「Layer の順序」 / "show the stack for <name>", "what's the layer order"

```bash
bash references/scripts/stack-plan.sh <name>
```

stack delivery の Epic 専用。各 Task の Layer、ブランチ、PR の base を表示。`--write` で position を保存、`--check` で検証。

---

## スクリプト失敗時

スクリプトの失敗時、または出力に解釈が必要な場合 (出力中のエラー、ユーザーからの「これは何を意味するか」等の質問) に限り、説明を補足。ただし必ず先にスクリプトを実行し、status や standup の出力を推測で作成しない。

`.claude/` ディレクトリ自体が不在の場合、プロジェクトは未初期化。次の実行をユーザーへ案内:
```bash
bash references/scripts/init.sh
```
