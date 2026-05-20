#!/usr/bin/env bash
# merge-port SessionStart hook
# Surface a brief context note when the cwd (or an ancestor) carries a
# .merge-port.yaml. Lets the model recommend merge-port commands without
# the user having to mention the tool.

set -e

dir="$(pwd)"
config=""
while [ "$dir" != "/" ]; do
  if [ -f "$dir/.merge-port.yaml" ]; then
    config="$dir/.merge-port.yaml"
    break
  fi
  dir="$(dirname "$dir")"
done

[ -z "$config" ] && exit 0

cat <<EOF
merge-port config detected: $config
Use \`merge-port\` (in dir) to start, \`merge-port --dry-run\` to preview routing,
\`merge-port validate\` to check ports and upstream reachability.
Skill 'merge-port' covers simple vs route mode, API-prefix discovery, and proc-compose integration.
EOF
