#!/bin/bash

echo "📅 日次 Standup - $(date '+%Y-%m-%d')"
echo "================================"
echo ""

today=$(date '+%Y-%m-%d')

echo "状況を取得中..."
echo ""
echo ""

# Frontmatter フィールドの値 (本文の行は無視)
fm_get() {
  awk -v k="$1" '
    NR==1 && /^---$/ {fm=1; next}
    fm && /^---$/    {exit}
    fm && index($0, k":")==1 {sub("^" k ": *", ""); print; exit}' "$2"
}

# Task の未充足の待機対象を "#N (status)" 形式で出力。着手可能な場合は空。
# merge delivery: depends_on の全 Task が closed。
# stack delivery: 直下の Layer が in-review または closed。
unmet_deps() {
  local task_file="$1" epic_dir dep dep_file dep_status pos f
  epic_dir=$(dirname "$task_file")
  if [ "$(fm_get delivery "$epic_dir/epic.md")" = "stack" ]; then
    pos=$(fm_get position "$task_file")
    if [ -z "$pos" ]; then echo "(position 未設定: stack-plan.sh を実行)"; return; fi
    [ "$pos" -le 1 ] && return
    for f in "$epic_dir"/[0-9]*.md; do
      [ "$(fm_get position "$f")" = "$((pos - 1))" ] || continue
      dep_status=$(fm_get status "$f")
      case "$dep_status" in in-review|closed) ;; *) echo "#$(basename "$f" .md) (${dep_status:-open})" ;; esac
      return
    done
    echo "(Layer $((pos - 1)) 不在)"
  else
    for dep in $(fm_get depends_on "$task_file" | tr -d '[],'); do
      dep_file="$epic_dir/$dep.md"
      if [ ! -f "$dep_file" ]; then echo "#$dep (不在)"; continue; fi
      dep_status=$(fm_get status "$dep_file")
      [ "$dep_status" = "closed" ] || echo "#$dep (${dep_status:-open})"
    done
  fi
}

echo "📝 本日の活動:"
echo "===================="
echo ""

# 本日更新のファイルを検索
recent_files=$(find .claude -name "*.md" -mtime -1 2>/dev/null)

if [ -n "$recent_files" ]; then
  # 種別ごとの計数
  prd_count=$(echo "$recent_files" | grep -c "/prds/" 2>/dev/null | tr -d '[:space:]')
  epic_count=$(echo "$recent_files" | grep -c "/epic.md" 2>/dev/null | tr -d '[:space:]')
  task_count=$(echo "$recent_files" | grep -c "/[0-9]*.md" 2>/dev/null | tr -d '[:space:]')
  update_count=$(echo "$recent_files" | grep -c "/updates/" 2>/dev/null | tr -d '[:space:]')
  prd_count=${prd_count:-0}; epic_count=${epic_count:-0}; task_count=${task_count:-0}; update_count=${update_count:-0}

  [ "$prd_count" -gt 0 ] && echo "  • PRD 変更: $prd_count 件"
  [ "$epic_count" -gt 0 ] && echo "  • Epic 更新: $epic_count 件"
  [ "$task_count" -gt 0 ] && echo "  • Task 作業: $task_count 件"
  [ "$update_count" -gt 0 ] && echo "  • 進捗更新の投稿: $update_count 件"
else
  echo "  本日の活動記録なし"
fi

echo ""
echo "🔄 現在進行中:"
# 稼働中の作業項目の表示
for updates_dir in .claude/epics/*/updates/*/; do
  [ -d "$updates_dir" ] || continue
  if [ -f "$updates_dir/progress.md" ]; then
    issue_num=$(basename "$updates_dir")
    epic_name=$(basename $(dirname $(dirname "$updates_dir")))
    completion=$(grep "^completion:" "$updates_dir/progress.md" | head -1 | sed 's/^completion: *//')
    echo "  • Issue #$issue_num ($epic_name) - ${completion:-0%} 完了"
  fi
done

echo ""
echo "⏭️ 次に着手可能な Task:"
# 着手可能な Task の上位 3 件を表示
count=0
for epic_dir in .claude/epics/*/; do
  [ -d "$epic_dir" ] || continue
  for task_file in "$epic_dir"[0-9]*.md; do
    [ -f "$task_file" ] || continue
    case "$(basename "$task_file" .md)" in *[!0-9]*) continue ;; esac
    status=$(fm_get status "$task_file")
    if [ "$status" != "open" ] && [ -n "$status" ]; then
      continue
    fi
    [ -z "$(unmet_deps "$task_file")" ] || continue

    task_name=$(fm_get name "$task_file")
    task_num=$(basename "$task_file" .md)
    echo "  • #$task_num - $task_name"
    ((count++))
    [ $count -ge 3 ] && break 2
  done
done

echo ""
echo "📊 簡易統計:"
total_tasks=$(find .claude/epics -name "[0-9]*.md" 2>/dev/null | wc -l)
open_tasks=$(find .claude/epics -name "[0-9]*.md" -exec grep -l "^status: *open" {} \; 2>/dev/null | wc -l)
review_tasks=$(find .claude/epics -name "[0-9]*.md" -exec grep -l "^status: *in-review" {} \; 2>/dev/null | wc -l)
closed_tasks=$(find .claude/epics -name "[0-9]*.md" -exec grep -l "^status: *closed" {} \; 2>/dev/null | wc -l)
echo "  Task: 未着手 $open_tasks、レビュー中 $review_tasks、クローズ済み $closed_tasks、総数 $total_tasks"

exit 0
