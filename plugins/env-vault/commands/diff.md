---
description: Compare keys between a .env file and its .env.vault to find added/removed/changed keys.
argument-hint: "[env-file] [vault-file] [--values]"
allowed-tools: Bash
---

Run `env-vault diff $ARGUMENTS`.

Default: `env-vault diff .env .env.vault`.

By default the diff only shows key names. Pass `--values` to show the actual changed values — useful in private terminals, dangerous in shared ones. Warn the user before adding `--values` if the conversation context suggests a shared screen, CI logs, or anything pipe-able to an untrusted sink.

After running, group findings:
- **Added** keys (in `.env`, missing in vault) → needs a re-seal.
- **Removed** keys (in vault, missing in `.env`) → either intentional pruning or an opened vault that has been edited; flag for the user.
- **Changed** values → re-seal recommended.

If anything would benefit from re-sealing, recommend the exact command: `env-vault seal .env -o .env.vault`. Do not run it yourself unless asked.
