#!/bin/bash

echo "📄 PRD 状況報告"
echo "===================="
echo ""

if [ ! -d ".claude/prds" ]; then
  echo "PRD ディレクトリ不在。"
  exit 0
fi

total=$(ls .claude/prds/*.md 2>/dev/null | wc -l)
[ $total -eq 0 ] && echo "PRD 不在。" && exit 0

# status 別の計数
backlog=0
in_progress=0
implemented=0

for file in .claude/prds/*.md; do
  [ -f "$file" ] || continue
  status=$(grep "^status:" "$file" | head -1 | sed 's/^status: *//')

  case "$status" in
    backlog|draft|"") ((backlog++)) ;;
    in-progress|active) ((in_progress++)) ;;
    implemented|completed|done) ((implemented++)) ;;
    *) ((backlog++)) ;;
  esac
done

echo "状況を取得中..."
echo ""
echo ""

# 図表の表示
echo "📊 分布:"
echo "================"

echo ""
echo "  Backlog:   $(printf '%-3d' $backlog) [$(printf '%0.s█' $(seq 1 $((backlog*20/total))))]"
echo "  進行中:    $(printf '%-3d' $in_progress) [$(printf '%0.s█' $(seq 1 $((in_progress*20/total))))]"
echo "  実装済:    $(printf '%-3d' $implemented) [$(printf '%0.s█' $(seq 1 $((implemented*20/total))))]"
echo ""
echo "  PRD 総数: $total"

# 直近の活動
echo ""
echo "📅 直近の PRD (最終更新順 5 件):"
ls -t .claude/prds/*.md 2>/dev/null | head -5 | while read file; do
  name=$(grep "^name:" "$file" | head -1 | sed 's/^name: *//')
  [ -z "$name" ] && name=$(basename "$file" .md)
  echo "  • $name"
done

# 提案
echo ""
echo "💡 次の操作:"
[ $backlog -gt 0 ] && echo "  • Backlog の PRD の Epic 化: /pm:prd-parse <name>"
[ $in_progress -gt 0 ] && echo "  • 進行中 PRD の進捗確認: /pm:epic-status <name>"
[ $total -eq 0 ] && echo "  • 最初の PRD の作成: /pm:prd-new <name>"

exit 0
