#!/bin/bash

epic_name="$1"

if [ -z "$epic_name" ]; then
  echo "❌ Epic 名の指定が必要"
  echo "使用法: /pm:epic-show <epic-name>"
  exit 1
fi

echo "Epic を取得中..."
echo ""
echo ""

epic_dir=".claude/epics/$epic_name"
epic_file="$epic_dir/epic.md"

if [ ! -f "$epic_file" ]; then
  echo "❌ Epic 不在: $epic_name"
  echo ""
  echo "利用可能な Epic:"
  for dir in .claude/epics/*/; do
    [ -d "$dir" ] && echo "  • $(basename "$dir")"
  done
  exit 1
fi

# Epic 詳細の表示
echo "📚 Epic: $epic_name"
echo "================================"
echo ""

# metadata の抽出
status=$(grep "^status:" "$epic_file" | head -1 | sed 's/^status: *//')
progress=$(grep "^progress:" "$epic_file" | head -1 | sed 's/^progress: *//')
github=$(grep "^github:" "$epic_file" | head -1 | sed 's/^github: *//')
created=$(grep "^created:" "$epic_file" | head -1 | sed 's/^created: *//')

echo "📊 metadata:"
echo "  状態: ${status:-planning}"
echo "  進捗: ${progress:-0%}"
[ -n "$github" ] && echo "  GitHub: $github"
echo "  作成日時: ${created:-不明}"
echo ""

# Task の表示
echo "📝 Task:"
task_count=0
open_count=0
closed_count=0

for task_file in "$epic_dir"/[0-9]*.md; do
  [ -f "$task_file" ] || continue

  task_num=$(basename "$task_file" .md)
  task_name=$(grep "^name:" "$task_file" | head -1 | sed 's/^name: *//')
  task_status=$(grep "^status:" "$task_file" | head -1 | sed 's/^status: *//')
  parallel=$(grep "^parallel:" "$task_file" | head -1 | sed 's/^parallel: *//')

  if [ "$task_status" = "closed" ] || [ "$task_status" = "completed" ]; then
    echo "  ✅ #$task_num - $task_name"
    ((closed_count++))
  elif [ "$task_status" = "in-review" ]; then
    echo "  🔍 #$task_num - $task_name (レビュー中)"
    ((open_count++))
  else
    echo "  ⬜ #$task_num - $task_name"
    [ "$parallel" = "true" ] && echo -n " (並列可)"
    ((open_count++))
  fi

  ((task_count++))
done

if [ $task_count -eq 0 ]; then
  echo "  Task 未作成"
  echo "  実行: /pm:epic-decompose $epic_name"
fi

echo ""
echo "📈 統計:"
echo "  Task 総数: $task_count"
echo "  未完了: $open_count"
echo "  close 済み: $closed_count"
[ $task_count -gt 0 ] && echo "  完了率: $((closed_count * 100 / task_count))%"

# 次の操作
echo ""
echo "💡 操作:"
[ $task_count -eq 0 ] && echo "  • Task へ分解: /pm:epic-decompose $epic_name"
[ -z "$github" ] && [ $task_count -gt 0 ] && echo "  • GitHub へ Sync: /pm:epic-sync $epic_name"
[ -n "$github" ] && [ "$status" != "completed" ] && echo "  • 作業開始: /pm:epic-start $epic_name"

exit 0
