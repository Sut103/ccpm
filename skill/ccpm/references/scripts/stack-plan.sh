#!/bin/bash
# Compute the layer order of a stack-mode epic: every task becomes one layer of a
# single linear stack. Tasks that already have a position keep it; tasks without one
# are appended on top in depends_on topological order (lowest task number first).
#
# Usage: stack-plan.sh <epic-name> [--write | --check]
#   (none)   print the plan
#   --write  also set `position:` in each task's frontmatter
#   --check  exit 1 unless every task has the position the plan gives it

epic_name="$1"
mode="${2:-}"

if [ -z "$epic_name" ]; then
  echo "❌ Please specify an epic name"
  echo "Usage: stack-plan.sh <epic-name> [--write | --check]"
  exit 1
fi

epic_dir=".claude/epics/$epic_name"
epic_file="$epic_dir/epic.md"

if [ ! -f "$epic_file" ]; then
  echo "❌ Epic not found: $epic_name"
  exit 1
fi

# Value of a frontmatter field (body lines are ignored)
fm_get() {
  awk -v k="$1" '
    NR==1 && /^---$/ {fm=1; next}
    fm && /^---$/    {exit}
    fm && index($0, k":")==1 {sub("^" k ": *", ""); print; exit}' "$2"
}

# Set a frontmatter field, adding it before the closing --- if missing
fm_set() {
  awk -v k="$1" -v v="$2" '
    NR==1 && /^---$/ {fm=1; print; next}
    fm && index($0, k":")==1 {print k": "v; done=1; next}
    fm && /^---$/    {if (!done) print k": "v; fm=0}
    {print}' "$3" > "$3.tmp" && mv "$3.tmp" "$3"
}

delivery=$(fm_get delivery "$epic_file")
if [ "$delivery" != "stack" ]; then
  echo "❌ Epic $epic_name does not use stack delivery (delivery: ${delivery:-merge})"
  exit 1
fi

# Task numbers (as integers) and their files; analysis and other files are skipped
tasks=""
for f in "$epic_dir"/[0-9]*.md; do
  [ -f "$f" ] || continue
  base=$(basename "$f" .md)
  case "$base" in *[!0-9]*) continue ;; esac
  tasks="$tasks $((10#$base))"
done
tasks=$(echo $tasks | tr ' ' '\n' | sort -n | tr '\n' ' ')

if [ -z "${tasks// /}" ]; then
  echo "❌ No tasks in epic: $epic_name"
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

# Tasks that already have a position keep their order
positioned=""
unpositioned=""
for t in $tasks; do
  pos=$(fm_get position "$(task_file "$t")")
  if [ -n "$pos" ]; then
    case "$pos" in *[!0-9]*) echo "❌ Task $t has an invalid position: $pos"; exit 1 ;; esac
    positioned="$positioned
$pos $t"
  else
    unpositioned="$unpositioned $t"
  fi
done

dup=$(echo "$positioned" | awk 'NF {print $1}' | sort -n | uniq -d | head -1)
if [ -n "$dup" ]; then
  echo "❌ Position $dup is used by more than one task"
  exit 1
fi

order=$(echo "$positioned" | awk 'NF' | sort -n | awk '{print $2}' | tr '\n' ' ')

# Append the rest: always take the lowest-numbered task whose dependencies are placed
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
    echo "❌ Circular or missing dependency among tasks:$remaining"
    exit 1
  fi
  order="$order $picked"
  remaining=$(echo " $remaining " | sed "s/ $picked / /")
done

# Every dependency must sit below the task that depends on it
placed=" "
for t in $order; do
  for d in $(task_deps "$t"); do
    case "$placed" in *" $d "*) ;; *)
      echo "❌ Task $t depends on $d, which is not below it in the stack"
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
    --check) [ "$current" != "$pos" ] && { echo "     ⚠️ position is '${current:-unset}', expected $pos"; status=1; } ;;
  esac
  prev="$num"
done

echo ""
case "$mode" in
  --write) echo "✅ Positions written for $pos tasks" ;;
  --check) [ $status -eq 0 ] && echo "✅ Positions match the stack plan" || echo "❌ Positions do not match. Run: stack-plan.sh $epic_name --write" ;;
esac

exit $status
