#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-readiness.sh"

echo "Getting status..."
echo ""
echo ""

echo "📋 Next Available Tasks"
echo "======================="
echo ""

# Find tasks that are open and Ready per lib-readiness.sh: zero unmet
# dependencies, or exactly one whose own readiness resolves the same way
# (it stacks a GitHub Stacked PR on that one dependency's branch — see
# execute.md § Starting a Full Epic). Everything else is Blocked.
found=0

for epic_dir in .claude/epics/*/; do
  [ -d "$epic_dir" ] || continue
  epic_name=$(basename "$epic_dir")

  for task_file in "$epic_dir"/[0-9]*.md; do
    [ -f "$task_file" ] || continue
    task_num=$(basename "$task_file" .md)

    # Check if task is open
    status=$(grep "^status:" "$task_file" | head -1 | sed 's/^status: *//')
    if [ "$status" != "open" ] && [ -n "$status" ]; then
      continue
    fi

    if [ "$(task_readiness "$epic_dir" "$task_num")" = "ready" ]; then
      task_name=$(grep "^name:" "$task_file" | head -1 | sed 's/^name: *//; s/^"//; s/"[[:space:]]*$//')
      parallel=$(grep "^parallel:" "$task_file" | head -1 | sed 's/^parallel: *//')
      unmet=$(task_unmet_deps "$epic_dir" "$task_num")

      echo "✅ Ready: #$task_num - $task_name"
      echo "   Epic: $epic_name"
      [ -n "$unmet" ] && echo "   📚 Stacks on #$unmet (not yet merged)"
      [ "$parallel" = "true" ] && echo "   🔄 Can run in parallel"
      echo ""
      ((found++))
    fi
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
