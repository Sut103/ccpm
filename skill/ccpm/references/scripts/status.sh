#!/bin/bash

echo "状況を取得中..."
echo ""
echo ""


echo "📊 プロジェクト状況"
echo "================"
echo ""

echo "📄 PRD:"
if [ -d ".claude/prds" ]; then
  total=$(ls .claude/prds/*.md 2>/dev/null | wc -l)
  echo "  総数: $total"
else
  echo "  PRD 不在"
fi

echo ""
echo "📚 Epic:"
if [ -d ".claude/epics" ]; then
  total=$(ls -d .claude/epics/*/ 2>/dev/null | grep -v '/archived/$' | wc -l)
  echo "  総数: $total"
else
  echo "  Epic 不在"
fi

echo ""
echo "📝 Task:"
if [ -d ".claude/epics" ]; then
  total=$(find .claude/epics -path "*/archived/*" -prune -o -name "[0-9]*.md" -print 2>/dev/null | wc -l)
  open=$(find .claude/epics -path "*/archived/*" -prune -o -name "[0-9]*.md" -print 2>/dev/null | xargs grep -l "^status: *open" 2>/dev/null | wc -l)
  in_review=$(find .claude/epics -path "*/archived/*" -prune -o -name "[0-9]*.md" -print 2>/dev/null | xargs grep -l "^status: *in-review" 2>/dev/null | wc -l)
  closed=$(find .claude/epics -path "*/archived/*" -prune -o -name "[0-9]*.md" -print 2>/dev/null | xargs grep -l "^status: *closed" 2>/dev/null | wc -l)
  echo "  未着手: $open"
  echo "  レビュー中: $in_review"
  echo "  クローズ済み: $closed"
  echo "  総数: $total"
else
  echo "  Task 不在"
fi

exit 0
