#!/bin/bash
# Shared dependency-readiness logic for next.sh / blocked.sh.
#
# A task is Ready if it has zero unmet (non-closed) dependencies, or exactly
# one whose dependency has already started (has its own worktree/branch —
# an updates/<dep>/execution.md file) — that one becomes its Stacked PR base
# (see execute.md § Starting a Full Epic, Step 2). A task only ever stacks
# on an already-started dependency, never on one that hasn't started yet, so
# this check never needs to look more than one level deep.

# Usage: task_readiness <epic_dir> <task_num>
# Echoes "ready" or "blocked". <epic_dir> must end with a trailing slash.
task_readiness() {
  local epic_dir="$1" task_num="$2"
  local task_file="${epic_dir}${task_num}.md"
  [ -f "$task_file" ] || { echo "ready"; return; }

  local status
  status=$(grep "^status:" "$task_file" | head -1 | sed 's/^status: *//')
  if [ "$status" = "closed" ] || [ -f "${epic_dir}updates/${task_num}/execution.md" ]; then
    echo "ready"   # closed (merged), or already started — either way, done resolving
    return
  fi

  local unmet
  unmet=$(task_unmet_deps "$epic_dir" "$task_num")
  local unmet_count
  unmet_count=$(echo "$unmet" | wc -w | tr -d ' ')

  if [ "$unmet_count" -ge 2 ]; then
    echo "blocked"
  elif [ "$unmet_count" -eq 1 ]; then
    if [ -f "${epic_dir}updates/${unmet}/execution.md" ]; then
      echo "ready"    # the one unmet dependency has started — stack on it
    else
      echo "blocked"  # hasn't started yet — nothing to stack on
    fi
  else
    echo "ready"
  fi
}

# Usage: task_unmet_deps <epic_dir> <task_num>
# Echoes the space-separated list of this task's own depends_on entries
# that aren't yet closed.
task_unmet_deps() {
  local epic_dir="$1" task_num="$2"
  local task_file="${epic_dir}${task_num}.md"
  [ -f "$task_file" ] || return
  local deps_line deps unmet=""
  deps_line=$(grep "^depends_on:" "$task_file" | head -1)
  deps=$(echo "$deps_line" | sed 's/^depends_on: *//' | sed 's/^\[//' | sed 's/\]$//' | sed 's/,/ /g' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
  for dep in $deps; do
    [ -f "${epic_dir}${dep}.md" ] || continue
    local dep_status
    dep_status=$(grep "^status:" "${epic_dir}${dep}.md" | head -1 | sed 's/^status: *//')
    [ "$dep_status" != "closed" ] && unmet="$unmet $dep"
  done
  echo "$unmet" | sed 's/^ *//'
}
