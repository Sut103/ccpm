#!/bin/bash

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

epic_name="$1"

if [ -z "$epic_name" ]; then
  echo "❌ Epic 名の指定が必要"
  echo "使用法: /pm:epic-status <epic-name>"
  echo ""
  echo "利用可能な Epic:"
  for dir in .claude/epics/*/; do
    [ -d "$dir" ] && echo "  • $(basename "$dir")"
  done
  exit 1
else
  # 指定 Epic の状況表示
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

  echo "📚 Epic 状況: $epic_name"
  echo "================================"
  echo ""

  # メタデータの抽出
  status=$(grep "^status:" "$epic_file" | head -1 | sed 's/^status: *//')
  progress=$(grep "^progress:" "$epic_file" | head -1 | sed 's/^progress: *//')
  github=$(grep "^github:" "$epic_file" | head -1 | sed 's/^github: *//')
  delivery=$(fm_get delivery "$epic_file")

  # Task の計数
  total=0
  open=0
  in_progress=0
  in_review=0
  closed=0
  blocked=0

  for task_file in "$epic_dir"/[0-9]*.md; do
    [ -f "$task_file" ] || continue
    case "$(basename "$task_file" .md)" in *[!0-9]*) continue ;; esac
    ((total++))

    task_status=$(fm_get status "$task_file")

    if [ "$task_status" = "closed" ] || [ "$task_status" = "completed" ]; then
      ((closed++))
    elif [ "$task_status" = "in-review" ]; then
      ((in_review++))
    elif [ "$task_status" = "in-progress" ]; then
      ((in_progress++))
    elif [ -n "$(unmet_deps "$task_file")" ]; then
      ((blocked++))
    else
      ((open++))
    fi
  done

  # 進捗バーの表示
  if [ $total -gt 0 ]; then
    percent=$((closed * 100 / total))
    filled=$((percent * 20 / 100))
    empty=$((20 - filled))

    echo -n "進捗: ["
    [ $filled -gt 0 ] && printf '%0.s█' $(seq 1 $filled)
    [ $empty -gt 0 ] && printf '%0.s░' $(seq 1 $empty)
    echo "] $percent%"
  else
    echo "進捗: Task 未作成"
  fi

  echo ""
  echo "📊 内訳:"
  echo "  Task 総数: $total"
  echo "  ✅ クローズ済み: $closed"
  echo "  🔍 レビュー中: $in_review"
  echo "  🛠️ 進行中: $in_progress"
  echo "  🔄 着手可能: $open"
  echo "  ⏸️ 阻害中: $blocked"

  echo "  📦 Delivery: ${delivery:-merge}"

  [ -n "$github" ] && echo ""
  [ -n "$github" ] && echo "🔗 GitHub: $github"
fi

exit 0
