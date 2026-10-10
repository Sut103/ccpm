#!/bin/bash
echo "Getting status..."
echo ""
echo ""

echo "📋 Next Available Tasks"
echo "======================="
echo ""

# Value of a frontmatter field (body lines are ignored)
fm_get() {
  awk -v k="$1" '
    NR==1 && /^---$/ {fm=1; next}
    fm && /^---$/    {exit}
    fm && index($0, k":")==1 {sub("^" k ": *", ""); print; exit}' "$2"
}

# What a task still waits for, as "#N (status)" words; empty when it can start.
# merge delivery: every depends_on task is closed.
# stack delivery: the layer directly below is in-review or closed.
unmet_deps() {
  local task_file="$1" epic_dir dep dep_file dep_status pos f
  epic_dir=$(dirname "$task_file")
  if [ "$(fm_get delivery "$epic_dir/epic.md")" = "stack" ]; then
    pos=$(fm_get position "$task_file")
    if [ -z "$pos" ]; then echo "(position unset: run stack-plan.sh)"; return; fi
    [ "$pos" -le 1 ] && return
    for f in "$epic_dir"/[0-9]*.md; do
      [ "$(fm_get position "$f")" = "$((pos - 1))" ] || continue
      dep_status=$(fm_get status "$f")
      case "$dep_status" in in-review|closed) ;; *) echo "#$(basename "$f" .md) (${dep_status:-open})" ;; esac
      return
    done
    echo "(layer $((pos - 1)) missing)"
  else
    for dep in $(fm_get depends_on "$task_file" | tr -d '[],'); do
      dep_file="$epic_dir/$dep.md"
      if [ ! -f "$dep_file" ]; then echo "#$dep (missing)"; continue; fi
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

    # Check if task is open
    status=$(fm_get status "$task_file")
    if [ "$status" != "open" ] && [ -n "$status" ]; then
      continue
    fi

    [ -z "$(unmet_deps "$task_file")" ] || continue

    task_name=$(fm_get name "$task_file")
    task_num=$(basename "$task_file" .md)
    parallel=$(fm_get parallel "$task_file")

    echo "✅ Ready: #$task_num - $task_name"
    echo "   Epic: $epic_name"
    [ "$parallel" = "true" ] && [ "$(fm_get delivery "${epic_dir}epic.md")" != "stack" ] && echo "   🔄 Can run in parallel"
    echo ""
    ((found++))
  done
done

if [ $found -eq 0 ]; then
  echo "No available tasks found."
  echo ""
  echo "💡 Suggestions:"
  echo "  • Check blocked tasks: /pm:blocked"
  echo "  • View all tasks: /pm:epic-list"
fi

echo ""
echo "📊 Summary: $found tasks ready to start"

exit 0
