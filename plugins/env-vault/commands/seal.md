---
description: Encrypt a .env file into a .env.vault. Prompts for password unless ENV_VAULT_KEY is set.
argument-hint: "[file] [-o output] [-p password]"
allowed-tools: Bash
---

Run `env-vault seal $ARGUMENTS`.

Before running:
1. If no file argument is given, default to `.env` and confirm with the user.
2. Refuse to seal a file that's already a vault (starts with `#:env-vault:v1:ruc`).
3. Recommend against passing `-p <password>` directly — the password ends up in shell history and the process table. Use the interactive prompt or `ENV_VAULT_KEY` env var instead.
4. Confirm `.env` is gitignored. If not, warn the user and offer to add it.
5. If a vault file already exists at the output path, confirm overwrite with the user before running.

After running, confirm the vault round-trips: `env-vault open <vault> -o /tmp/.env.check` and `diff` against the original. If they don't match, surface the error and stop — don't commit a broken vault.
