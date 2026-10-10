#!/bin/bash

query="$1"

if [ -z "$query" ]; then
  echo "❌ 検索語の指定が必要"
  echo "使用法: /pm:search <query>"
  exit 1
fi

echo "'$query' を検索中..."
echo ""
echo ""

echo "🔍 検索結果: '$query'"
echo "================================"
echo ""

# PRD 内の検索
if [ -d ".claude/prds" ]; then
  echo "📄 PRD:"
  results=$(grep -l -i "$query" .claude/prds/*.md 2>/dev/null)
  if [ -n "$results" ]; then
    for file in $results; do
      name=$(basename "$file" .md)
      matches=$(grep -c -i "$query" "$file")
      echo "  • $name ($matches 件一致)"
    done
  else
    echo "  一致なし"
  fi
  echo ""
fi

# Epic 内の検索
if [ -d ".claude/epics" ]; then
  echo "📚 Epic:"
  results=$(find .claude/epics -name "epic.md" -exec grep -l -i "$query" {} \; 2>/dev/null)
  if [ -n "$results" ]; then
    for file in $results; do
      epic_name=$(basename $(dirname "$file"))
      matches=$(grep -c -i "$query" "$file")
      echo "  • $epic_name ($matches 件一致)"
    done
  else
    echo "  一致なし"
  fi
  echo ""
fi

# Task 内の検索
if [ -d ".claude/epics" ]; then
  echo "📝 Task:"
  results=$(find .claude/epics -name "[0-9]*.md" -exec grep -l -i "$query" {} \; 2>/dev/null | head -10)
  if [ -n "$results" ]; then
    for file in $results; do
      epic_name=$(basename $(dirname "$file"))
      task_num=$(basename "$file" .md)
      echo "  • Task #$task_num ($epic_name)"
    done
  else
    echo "  一致なし"
  fi
fi

# 要約
total=$(find .claude -name "*.md" -exec grep -l -i "$query" {} \; 2>/dev/null | wc -l)
echo ""
echo "📊 一致ファイル総数: $total"

exit 0
