#!/bin/bash

echo "PM システムを検証中..."
echo ""
echo ""

echo "🔍 PM システムの検証"
echo "======================="
echo ""

errors=0
warnings=0

# ディレクトリ構成の確認
echo "📁 ディレクトリ構成:"
[ -d ".claude" ] && echo "  ✅ .claude ディレクトリあり" || { echo "  ❌ .claude ディレクトリ不在"; ((errors++)); }
[ -d ".claude/prds" ] && echo "  ✅ PRD ディレクトリあり" || echo "  ⚠️ PRD ディレクトリ不在"
[ -d ".claude/epics" ] && echo "  ✅ Epic ディレクトリあり" || echo "  ⚠️ Epic ディレクトリ不在"
[ -d ".claude/rules" ] && echo "  ✅ Rules ディレクトリあり" || echo "  ⚠️ Rules ディレクトリ不在"
echo ""

# 孤立ファイルの確認
echo "🗂️ データ整合性:"

# Epic に epic.md があるか確認
for epic_dir in .claude/epics/*/; do
  [ -d "$epic_dir" ] || continue
  if [ ! -f "$epic_dir/epic.md" ]; then
    echo "  ⚠️ $(basename "$epic_dir") に epic.md 不在"
    ((warnings++))
  fi
done

# Epic に属さない Task の確認
orphaned=$(find .claude -name "[0-9]*.md" -not -path ".claude/epics/*/*" 2>/dev/null | wc -l)
[ $orphaned -gt 0 ] && echo "  ⚠️ 孤立 Task ファイル $orphaned 件を検出" && ((warnings++))

# 破損参照の確認
echo ""
echo "🔗 参照確認:"

for task_file in .claude/epics/*/[0-9]*.md; do
  [ -f "$task_file" ] || continue

  deps_line=$(grep "^depends_on:" "$task_file" | head -1)
  if [ -n "$deps_line" ]; then
    deps=$(echo "$deps_line" | sed 's/^depends_on: *//' | sed 's/^\[//' | sed 's/\]$//' | sed 's/,/ /g' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
    [ -z "$deps" ] && deps=""
  else
    deps=""
  fi
  if [ -n "$deps" ] && [ "$deps" != "depends_on:" ]; then
    epic_dir=$(dirname "$task_file")
    for dep in $deps; do
      if [ ! -f "$epic_dir/$dep.md" ]; then
        echo "  ⚠️ Task $(basename "$task_file" .md) が不在の Task を参照: $dep"
        ((warnings++))
      fi
    done
  fi
done

if [ $warnings -eq 0 ] && [ $errors -eq 0 ]; then
  echo "  ✅ 全参照が有効"
fi

# Frontmatter の確認
echo ""
echo "📝 Frontmatter 検証:"
invalid=0

for file in $(find .claude -name "*.md" -path "*/epics/*" -o -path "*/prds/*" 2>/dev/null); do
  if ! grep -q "^---" "$file"; then
    echo "  ⚠️ Frontmatter 不在: $(basename "$file")"
    ((invalid++))
  fi
done

[ $invalid -eq 0 ] && echo "  ✅ 全ファイルに Frontmatter あり"

# Delivery Mode、Task の status 値、stack の position の確認
echo ""
echo "📦 Delivery と Status:"
delivery_issues=0

for epic_dir in .claude/epics/*/; do
  [ -f "$epic_dir/epic.md" ] || continue
  epic_name=$(basename "$epic_dir")
  delivery=$(awk 'NR==1 && /^---$/ {fm=1; next} fm && /^---$/ {exit} fm && /^delivery:/ {sub(/^delivery: */, ""); print; exit}' "$epic_dir/epic.md")

  case "${delivery:-merge}" in
    merge|stack) ;;
    *) echo "  ⚠️ Epic $epic_name の delivery が不正: $delivery (merge または stack が必要)"; ((warnings++)); ((delivery_issues++)) ;;
  esac

  for task_file in "$epic_dir"[0-9]*.md; do
    [ -f "$task_file" ] || continue
    case "$(basename "$task_file" .md)" in *[!0-9]*) continue ;; esac
    task_status=$(awk 'NR==1 && /^---$/ {fm=1; next} fm && /^---$/ {exit} fm && /^status:/ {sub(/^status: */, ""); print; exit}' "$task_file")
    case "$task_status" in
      open|in-progress|closed) ;;
      in-review)
        if [ "$delivery" != "stack" ]; then
          echo "  ⚠️ Task $(basename "$task_file" .md) が in-review だが、Epic $epic_name は stack delivery 非対象"
          ((warnings++)); ((delivery_issues++))
        fi ;;
      *) echo "  ⚠️ Task $(basename "$task_file" .md) の status が不正: ${task_status:-unset}"; ((warnings++)); ((delivery_issues++)) ;;
    esac
  done

  if [ "$delivery" = "stack" ] && ls "$epic_dir"[0-9]*.md >/dev/null 2>&1; then
    if ! bash "$(dirname "$0")/stack-plan.sh" "$epic_name" --check >/dev/null 2>&1; then
      echo "  ⚠️ $epic_name の stack の position が計画と不一致。実行: stack-plan.sh $epic_name"
      ((warnings++)); ((delivery_issues++))
    fi
  fi
done

[ $delivery_issues -eq 0 ] && echo "  ✅ Delivery Mode、status、stack の position が全て有効"

# 要約
echo ""
echo "📊 検証要約:"
echo "  エラー: $errors"
echo "  警告: $warnings"
echo "  不正ファイル: $invalid"

if [ $errors -eq 0 ] && [ $warnings -eq 0 ] && [ $invalid -eq 0 ]; then
  echo ""
  echo "✅ システム正常"
else
  echo ""
  echo "💡 /pm:clean の実行で一部問題を自動修正"
fi

exit 0
