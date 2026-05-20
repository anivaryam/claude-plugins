#!/usr/bin/env bash
# tunnel SessionStart hook
# Reports whether a tunnel config exists (~/.tunnel/config.yml) and surfaces
# any active daemons in the user's runtime dir. Silent if neither is present.

set -e

config="${HOME}/.tunnel/config.yml"
has_config=0
[ -f "$config" ] && has_config=1

runtime_dir="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/tunnel"
[ -d "$runtime_dir" ] || runtime_dir="${TMPDIR:-/tmp}/tunnel-$(id -u)"
active=""
if [ -d "$runtime_dir" ]; then
  active="$(ls "$runtime_dir"/tunnel-*.sock 2>/dev/null | wc -l | tr -d ' ')"
fi

if [ "$has_config" -eq 0 ] && [ "${active:-0}" -eq 0 ]; then
  exit 0
fi

note=""
if [ "$has_config" -eq 1 ]; then
  server="$(grep -E '^server_url:' "$config" 2>/dev/null | head -1 | sed 's/^server_url:[[:space:]]*//')"
  note+="tunnel config present (server: ${server:-unset}). Run \`tunnel doctor\` to verify relay reachability."$'\n'
fi
if [ "${active:-0}" -gt 0 ]; then
  note+="${active} tunnel daemon(s) currently active in $runtime_dir. Inspect with \`tunnel list\` or \`tunnel daemon status\`."$'\n'
fi

[ -n "$note" ] && printf '%s' "$note"
exit 0
