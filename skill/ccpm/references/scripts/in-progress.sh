#!/bin/bash
echo "状況を取得中..."
echo ""
echo ""

echo "🔄 進行中の作業"
echo "==================="
echo ""

# updates ディレクトリ内の稼働中作業を確認
found=0

if [ -d ".claude/epics" ]; then
  for updates_dir in .claude/epics/*/updates/*/; do
    [ -d "$updates_dir" ] || continue

    issue_num=$(basename "$updates_dir")
    epic_name=$(basename $(dirname $(dirname "$updates_dir")))

    if [ -f "$updates_dir/progress.md" ]; then
      completion=$(grep "^completion:" "$updates_dir/progress.md" | head -1 | sed 's/^completion: *//')
      [ -z "$completion" ] && completion="0%"

      # Task ファイルから Task 名を取得
      task_file=".claude/epics/$epic_name/$issue_num.md"
      if [ -f "$task_file" ]; then
        task_name=$(grep "^name:" "$task_file" | head -1 | sed 's/^name: *//')
      else
        task_name="不明な Task"
      fi

      echo "📝 Issue #$issue_num - $task_name"
      echo "   Epic: $epic_name"
      echo "   進捗: $completion 完了"

      # 直近の更新を確認
      if [ -f "$updates_dir/progress.md" ]; then
        last_update=$(grep "^last_sync:" "$updates_dir/progress.md" | head -1 | sed 's/^last_sync: *//')
        [ -n "$last_update" ] && echo "   最終更新: $last_update"
      fi

      echo ""
      ((found++))
    fi
  done
fi

# PR が open の Task (stack delivery)
review_found=0
for task_file in .claude/epics/*/[0-9]*.md; do
  [ -f "$task_file" ] || continue
  grep -q "^status: *in-review" "$task_file" || continue
  [ $review_found -eq 0 ] && echo "🔍 レビュー中:"
  task_num=$(basename "$task_file" .md)
  task_name=$(grep "^name:" "$task_file" | head -1 | sed 's/^name: *//')
  pr=$(grep "^pr:" "$task_file" | head -1 | sed 's/^pr: *//')
  echo "   • #$task_num - $task_name${pr:+ ($pr)}"
  ((review_found++))
done
[ $review_found -gt 0 ] && echo ""

# 進行中の Epic も確認
echo "📚 進行中の Epic:"
for epic_dir in .claude/epics/*/; do
  [ -d "$epic_dir" ] || continue
  [ -f "$epic_dir/epic.md" ] || continue

  status=$(grep "^status:" "$epic_dir/epic.md" | head -1 | sed 's/^status: *//')
  if [ "$status" = "in-progress" ] || [ "$status" = "active" ]; then
    epic_name=$(grep "^name:" "$epic_dir/epic.md" | head -1 | sed 's/^name: *//')
    progress=$(grep "^progress:" "$epic_dir/epic.md" | head -1 | sed 's/^progress: *//')
    [ -z "$epic_name" ] && epic_name=$(basename "$epic_dir")
    [ -z "$progress" ] && progress="0%"

    echo "   • $epic_name - $progress 完了"
  fi
done

echo ""
if [ $found -eq 0 ]; then
  echo "稼働中の作業項目なし。"
  echo ""
  echo "💡 作業開始: /pm:next"
else
  echo "📊 稼働中の項目合計: $found"
fi

exit 0
