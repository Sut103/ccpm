#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib-readiness.sh"

echo "Getting tasks..."
echo ""
echo ""

echo "🚫 Blocked Tasks"
echo "================"
echo ""

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

    # Blocked per lib-readiness.sh: two or more unmet dependencies, or
    # chained onto a dependency that is itself Blocked (see execute.md §
    # Starting a Full Epic — a task with at most one *resolvable* unmet
    # dependency is Ready instead, since it stacks a Stacked PR on it).
    if [ "$(task_readiness "$epic_dir" "$task_num")" = "blocked" ]; then
      task_name=$(grep "^name:" "$task_file" | head -1 | sed 's/^name: *//; s/^"//; s/"[[:space:]]*$//')
      deps_line=$(grep "^depends_on:" "$task_file" | head -1)
      deps=$(echo "$deps_line" | sed 's/^depends_on: *//' | sed 's/^\[//' | sed 's/\]$//' | sed 's/,/ /g' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
      unmet=$(task_unmet_deps "$epic_dir" "$task_num")
      unmet_count=$(echo "$unmet" | wc -w | tr -d ' ')

      echo "⏸️ Task #$task_num - $task_name"
      echo "   Epic: $epic_name"
      if [ "$unmet_count" -ge 2 ]; then
        echo "   Blocked by: [$deps] ($unmet_count still open — a branch can only stack on one)"
      else
        echo "   Blocked by: [$deps] (#$unmet hasn't started yet — nothing to stack on)"
      fi
      echo "   Waiting for: $unmet"
      echo ""
      ((found++))
    fi
  done
done

if [ $found -eq 0 ]; then
  echo "No blocked tasks found!"
  echo ""
  echo "💡 All tasks with dependencies are either completed or in progress."
else
  echo "📊 Total blocked: $found tasks"
fi

exit 0
