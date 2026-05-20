#!/usr/bin/env bash
# proc-compose SessionStart hook
# Walk up from cwd looking for proc-compose.yml / proc-compose.yaml.
# When found, surface a brief context note so the model knows the project
# uses proc-compose without the user having to mention it.

set -e

dir="$(pwd)"
config=""
while [ "$dir" != "/" ]; do
  for candidate in "$dir/proc-compose.yml" "$dir/proc-compose.yaml"; do
    if [ -f "$candidate" ]; then
      config="$candidate"
      break 2
    fi
  done
  dir="$(dirname "$dir")"
done

if [ -z "$config" ]; then
  exit 0
fi

if ! command -v proc-compose >/dev/null 2>&1; then
  cat <<EOF
proc-compose config detected at $config but the \`proc-compose\` binary is not on PATH.
Install it with: /proc-compose:install   (uses brokit if available, else upstream install.sh)
EOF
  exit 0
fi

# Stable, deterministic process list — same logic as `proc-compose list` but
# without requiring the binary on PATH (the model may want to suggest install).
processes="$(grep -E '^  [a-zA-Z_-]+:' "$config" 2>/dev/null | sed 's/^  //;s/:.*//' | tr '\n' ' ' | sed 's/ $//')"

cat <<EOF
proc-compose config detected: $config
Processes defined: ${processes:-<none parsed>}
Use \`proc-compose up\` to start, \`proc-compose status\` for daemon state.
Skill 'proc-compose' covers config authoring, lifecycle, readiness probes, and cloud deploy.
EOF
