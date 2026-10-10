# !/bin/bash
# PRD ディレクトリの存在確認
if [ ! -d ".claude/prds" ]; then
  echo "📁 PRD ディレクトリ不在。最初の PRD の作成: /pm:prd-new <feature-name>"
  exit 0
fi

# PRD ファイルの確認
if ! ls .claude/prds/*.md >/dev/null 2>&1; then
  echo "📁 PRD 不在。最初の PRD の作成: /pm:prd-new <feature-name>"
  exit 0
fi

# 計数器の初期化
backlog_count=0
in_progress_count=0
implemented_count=0
total_count=0

echo "PRD を取得中..."
echo ""
echo ""


echo "📋 PRD 一覧"
echo "==========="
echo ""

# status 群別に表示
echo "🔍 Backlog の PRD:"
for file in .claude/prds/*.md; do
  [ -f "$file" ] || continue
  status=$(grep "^status:" "$file" | head -1 | sed 's/^status: *//')
  if [ "$status" = "backlog" ] || [ "$status" = "draft" ] || [ -z "$status" ]; then
    name=$(grep "^name:" "$file" | head -1 | sed 's/^name: *//')
    desc=$(grep "^description:" "$file" | head -1 | sed 's/^description: *//')
    [ -z "$name" ] && name=$(basename "$file" .md)
    [ -z "$desc" ] && desc="説明なし"
    # echo "   📋 $name - $desc"
    echo "   📋 $file - $desc"
    ((backlog_count++))
  fi
  ((total_count++))
done
[ $backlog_count -eq 0 ] && echo "   (なし)"

echo ""
echo "🔄 進行中の PRD:"
for file in .claude/prds/*.md; do
  [ -f "$file" ] || continue
  status=$(grep "^status:" "$file" | head -1 | sed 's/^status: *//')
  if [ "$status" = "in-progress" ] || [ "$status" = "active" ]; then
    name=$(grep "^name:" "$file" | head -1 | sed 's/^name: *//')
    desc=$(grep "^description:" "$file" | head -1 | sed 's/^description: *//')
    [ -z "$name" ] && name=$(basename "$file" .md)
    [ -z "$desc" ] && desc="説明なし"
    # echo "   📋 $name - $desc"
    echo "   📋 $file - $desc"
    ((in_progress_count++))
  fi
done
[ $in_progress_count -eq 0 ] && echo "   (なし)"

echo ""
echo "✅ 実装済みの PRD:"
for file in .claude/prds/*.md; do
  [ -f "$file" ] || continue
  status=$(grep "^status:" "$file" | head -1 | sed 's/^status: *//')
  if [ "$status" = "implemented" ] || [ "$status" = "completed" ] || [ "$status" = "done" ]; then
    name=$(grep "^name:" "$file" | head -1 | sed 's/^name: *//')
    desc=$(grep "^description:" "$file" | head -1 | sed 's/^description: *//')
    [ -z "$name" ] && name=$(basename "$file" .md)
    [ -z "$desc" ] && desc="説明なし"
    # echo "   📋 $name - $desc"
    echo "   📋 $file - $desc"
    ((implemented_count++))
  fi
done
[ $implemented_count -eq 0 ] && echo "   (なし)"

# 要約の表示
echo ""
echo "📊 PRD 要約"
echo "   PRD 総数: $total_count"
echo "   Backlog: $backlog_count"
echo "   進行中: $in_progress_count"
echo "   実装済み: $implemented_count"

exit 0
