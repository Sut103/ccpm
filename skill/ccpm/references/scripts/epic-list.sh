#!/bin/bash
echo "Epic を取得中..."
echo ""
echo ""

[ ! -d ".claude/epics" ] && echo "📁 Epic directory 不在。最初の Epic の作成: /pm:prd-parse <feature-name>" && exit 0
[ -z "$(ls -d .claude/epics/*/ 2>/dev/null)" ] && echo "📁 Epic 不在。最初の Epic の作成: /pm:prd-parse <feature-name>" && exit 0

echo "📚 プロジェクトの Epic"
echo "================"
echo ""

# status 別に Epic を格納する配列の初期化
planning_epics=""
in_progress_epics=""
completed_epics=""

# 全 Epic の処理
for dir in .claude/epics/*/; do
  [ -d "$dir" ] || continue
  [ -f "$dir/epic.md" ] || continue

  # metadata の抽出
  n=$(grep "^name:" "$dir/epic.md" | head -1 | sed 's/^name: *//')
  s=$(grep "^status:" "$dir/epic.md" | head -1 | sed 's/^status: *//' | tr '[:upper:]' '[:lower:]')
  p=$(grep "^progress:" "$dir/epic.md" | head -1 | sed 's/^progress: *//')
  g=$(grep "^github:" "$dir/epic.md" | head -1 | sed 's/^github: *//')

  # 既定値
  [ -z "$n" ] && n=$(basename "$dir")
  [ -z "$p" ] && p="0%"

  # Task の計数
  t=$(ls "$dir"/[0-9]*.md 2>/dev/null | wc -l)

  # GitHub Issue 番号があれば付加して出力を整形
  if [ -n "$g" ]; then
    i=$(echo "$g" | grep -o '/[0-9]*$' | tr -d '/')
    entry="   📋 ${dir}epic.md (#$i) - $p 完了 ($t Task)"
  else
    entry="   📋 ${dir}epic.md - $p 完了 ($t Task)"
  fi

  # status 別に分類 (多様な status 値に対応)
  case "$s" in
    planning|draft|"")
      planning_epics="${planning_epics}${entry}\n"
      ;;
    in-progress|in_progress|active|started)
      in_progress_epics="${in_progress_epics}${entry}\n"
      ;;
    completed|complete|done|closed|finished)
      completed_epics="${completed_epics}${entry}\n"
      ;;
    *)
      # 未知の status は planning 扱い
      planning_epics="${planning_epics}${entry}\n"
      ;;
  esac
done

# 分類済み Epic の表示
echo "📝 計画中:"
if [ -n "$planning_epics" ]; then
  echo -e "$planning_epics" | sed '/^$/d'
else
  echo "   (なし)"
fi

echo ""
echo "🚀 進行中:"
if [ -n "$in_progress_epics" ]; then
  echo -e "$in_progress_epics" | sed '/^$/d'
else
  echo "   (なし)"
fi

echo ""
echo "✅ 完了:"
if [ -n "$completed_epics" ]; then
  echo -e "$completed_epics" | sed '/^$/d'
else
  echo "   (なし)"
fi

# 要約
echo ""
echo "📊 要約"
total=$(ls -d .claude/epics/*/ 2>/dev/null | wc -l)
tasks=$(find .claude/epics -name "[0-9]*.md" 2>/dev/null | wc -l)
echo "   Epic 総数: $total"
echo "   Task 総数: $tasks"

exit 0
