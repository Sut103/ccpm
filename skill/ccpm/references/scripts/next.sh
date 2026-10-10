#!/bin/bash
echo "状況を取得中..."
echo ""
echo ""

echo "📋 次に着手可能な Task"
echo "======================="
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

found=0

for epic_dir in .claude/epics/*/; do
  [ -d "$epic_dir" ] || continue
  epic_name=$(basename "$epic_dir")

  for task_file in "$epic_dir"[0-9]*.md; do
    [ -f "$task_file" ] || continue
    case "$(basename "$task_file" .md)" in *[!0-9]*) continue ;; esac

    # Task が open か確認
    status=$(fm_get status "$task_file")
    if [ "$status" != "open" ] && [ -n "$status" ]; then
      continue
    fi

    [ -z "$(unmet_deps "$task_file")" ] || continue

    task_name=$(fm_get name "$task_file")
    task_num=$(basename "$task_file" .md)
    parallel=$(fm_get parallel "$task_file")

    echo "✅ 着手可能: #$task_num - $task_name"
    echo "   Epic: $epic_name"
    [ "$parallel" = "true" ] && [ "$(fm_get delivery "${epic_dir}epic.md")" != "stack" ] && echo "   🔄 並列実行可"
    echo ""
    ((found++))
  done
done

if [ $found -eq 0 ]; then
  echo "着手可能な Task なし。"
  echo ""
  echo "💡 提案:"
  echo "  • 阻害中の Task の確認: /pm:blocked"
  echo "  • 全 Task の表示: /pm:epic-list"
fi

echo ""
echo "📊 要約: 着手可能な Task $found 件"

exit 0
