#!/bin/bash
# stack delivery の Epic の Layer 順序を算出: 全 Task が単一の直線的 stack の一 Layer となる。
# position を持つ Task はその値を維持し、持たない Task は depends_on のトポロジカル順
# (Task 番号の小さい順) で上に追加。
#
# Usage: stack-plan.sh <epic-name> [--write | --check]
#   (なし)   計画を表示
#   --write  各 Task の Frontmatter に `position:` も設定
#   --check  全 Task の position が計画と一致しない場合 exit 1

epic_name="$1"
mode="${2:-}"

if [ -z "$epic_name" ]; then
  echo "❌ Epic 名の指定が必要"
  echo "使用法: stack-plan.sh <epic-name> [--write | --check]"
  exit 1
fi

epic_dir=".claude/epics/$epic_name"
epic_file="$epic_dir/epic.md"

if [ ! -f "$epic_file" ]; then
  echo "❌ Epic 不在: $epic_name"
  exit 1
fi

# Frontmatter フィールドの値 (本文の行は無視)
fm_get() {
  awk -v k="$1" '
    NR==1 && /^---$/ {fm=1; next}
    fm && /^---$/    {exit}
    fm && index($0, k":")==1 {sub("^" k ": *", ""); print; exit}' "$2"
}

# Frontmatter フィールドを設定。不在の場合は閉じの --- の直前に追加
fm_set() {
  awk -v k="$1" -v v="$2" '
    NR==1 && /^---$/ {fm=1; print; next}
    fm && index($0, k":")==1 {print k": "v; done=1; next}
    fm && /^---$/    {if (!done) print k": "v; fm=0}
    {print}' "$3" > "$3.tmp" && mv "$3.tmp" "$3"
}

delivery=$(fm_get delivery "$epic_file")
if [ "$delivery" != "stack" ]; then
  echo "❌ Epic $epic_name は stack delivery 非対象 (delivery: ${delivery:-merge})"
  exit 1
fi

# Task 番号 (整数) とそのファイル。分析ファイル等は除外
tasks=""
for f in "$epic_dir"/[0-9]*.md; do
  [ -f "$f" ] || continue
  base=$(basename "$f" .md)
  case "$base" in *[!0-9]*) continue ;; esac
  tasks="$tasks $((10#$base))"
done
tasks=$(echo $tasks | tr ' ' '\n' | sort -n | tr '\n' ' ')

if [ -z "${tasks// /}" ]; then
  echo "❌ Epic 内に Task なし: $epic_name"
  exit 1
fi

task_file() {
  for f in "$epic_dir"/[0-9]*.md; do
    base=$(basename "$f" .md)
    case "$base" in *[!0-9]*) continue ;; esac
    [ "$((10#$base))" = "$1" ] && { echo "$f"; return; }
  done
}

task_deps() {
  for d in $(fm_get depends_on "$(task_file "$1")" | grep -oE '[0-9]+'); do
    echo $((10#$d))
  done
}

# position を持つ Task は順序を維持
positioned=""
unpositioned=""
for t in $tasks; do
  pos=$(fm_get position "$(task_file "$t")")
  if [ -n "$pos" ]; then
    case "$pos" in *[!0-9]*) echo "❌ Task $t の position が不正: $pos"; exit 1 ;; esac
    positioned="$positioned
$pos $t"
  else
    unpositioned="$unpositioned $t"
  fi
done

dup=$(echo "$positioned" | awk 'NF {print $1}' | sort -n | uniq -d | head -1)
if [ -n "$dup" ]; then
  echo "❌ Position $dup が複数 Task で重複"
  exit 1
fi

order=$(echo "$positioned" | awk 'NF' | sort -n | awk '{print $2}' | tr '\n' ' ')

# 残りを追加: 依存先が配置済みの Task のうち、常に最小番号の Task を選択
remaining="$unpositioned"
while [ -n "${remaining// /}" ]; do
  picked=""
  for t in $remaining; do
    ready=1
    for d in $(task_deps "$t"); do
      case " $order " in *" $d "*) ;; *) ready=0; break ;; esac
    done
    [ $ready -eq 1 ] && { picked=$t; break; }
  done
  if [ -z "$picked" ]; then
    echo "❌ Task 間に循環依存または依存先の欠落:$remaining"
    exit 1
  fi
  order="$order $picked"
  remaining=$(echo " $remaining " | sed "s/ $picked / /")
done

# 全依存先は依存元 Task より下位に配置必須
placed=" "
for t in $order; do
  for d in $(task_deps "$t"); do
    case "$placed" in *" $d "*) ;; *)
      echo "❌ Task $t は $d に依存するが、$d が stack 内で下位にない"
      exit 1 ;;
    esac
  done
  placed="$placed$t "
done

echo "🥞 Stack: $epic_name"
echo "================================"
echo ""

status=0
pos=0
prev=""
for t in $order; do
  pos=$((pos + 1))
  f=$(task_file "$t")
  num=$(basename "$f" .md)
  name=$(fm_get name "$f")
  task_status=$(fm_get status "$f")
  current=$(fm_get position "$f")
  if [ -z "$prev" ]; then base="main"; else base="epic/$epic_name/$prev"; fi

  echo "  $pos. #$num - $name [${task_status:-open}]"
  echo "     branch: epic/$epic_name/$num  base: $base"

  case "$mode" in
    --write) [ "$current" != "$pos" ] && fm_set position "$pos" "$f" ;;
    --check) [ "$current" != "$pos" ] && { echo "     ⚠️ position は '${current:-未設定}'、期待値は $pos"; status=1; } ;;
  esac
  prev="$num"
done

echo ""
case "$mode" in
  --write) echo "✅ $pos Task の position を書込" ;;
  --check) [ $status -eq 0 ] && echo "✅ position は stack 計画と一致" || echo "❌ position 不一致。実行: stack-plan.sh $epic_name --write" ;;
esac

exit $status
