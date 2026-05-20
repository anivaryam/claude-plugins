#!/usr/bin/env bash
# env-vault SessionStart hook
# Surface a brief context note when the cwd holds an .env.vault file
# (or other *.vault files). Encourages the model to suggest env-vault
# commands without the user mentioning the tool.

set -e

dir="$(pwd)"
vaults="$(ls "$dir"/*.vault 2>/dev/null | head -3)"
[ -z "$vaults" ] && exit 0

# Count keys without prompting for password — uses `env-vault keys` if available,
# but only if a non-interactive password source exists (env var). Otherwise just
# list the vault paths.
note="env-vault vault(s) detected:\n"
while IFS= read -r v; do
  note+="  - $v\n"
done <<< "$vaults"

if [ -n "$ENV_VAULT_KEY" ] && command -v env-vault >/dev/null 2>&1; then
  first="$(echo "$vaults" | head -1)"
  if keys="$(env-vault keys "$first" 2>/dev/null)"; then
    count="$(echo "$keys" | wc -l | tr -d ' ')"
    note+="$first holds ${count} key(s) (ENV_VAULT_KEY in env).\n"
  fi
fi

note+="Use \`env-vault open <vault>\` to decrypt, \`env-vault diff\` to spot drift, \`env-vault keys <vault>\` to list keys."

printf '%b\n' "$note"
exit 0
