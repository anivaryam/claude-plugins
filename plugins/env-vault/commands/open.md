---
description: Decrypt a .env.vault into a plaintext .env. Reads password from prompt, ENV_VAULT_KEY, or -p flag.
argument-hint: "[file] [-o output] [-p password]"
allowed-tools: Bash
---

Run `env-vault open $ARGUMENTS`.

Before running:
1. If no file argument is given, default to `.env.vault` and confirm with the user.
2. If an output file already exists and would be overwritten, confirm with the user first — the existing plaintext could have unsaved changes.
3. Discourage `-p <password>` in interactive shells (process table, history). For CI, prefer `ENV_VAULT_KEY=...` set by the secret store.

After running, confirm the output file exists and is non-empty (`test -s <output>`). If the user is in a CI-like context, recommend sourcing the file: `set -a; . ./.env; set +a`.

If decrypt fails with `authentication failed`, the password is wrong or the vault is corrupted. Do not retry blindly — ask the user to verify the password source.
