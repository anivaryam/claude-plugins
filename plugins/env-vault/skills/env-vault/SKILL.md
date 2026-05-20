---
name: env-vault
description: Use when encrypting `.env` files into committable vault files and back — sharing secrets via git, decrypting in CI, reading a single key in scripts, diffing plaintext vs vault to spot drift. Triggers on `env-vault` CLI invocations, `.env.vault` files in the repo, `ENV_VAULT_KEY` env var references, "encrypted env", "commit secrets safely", "decrypt env in CI", or any setup mixing plaintext `.env` (gitignored) with `.env.vault` (committed). Covers seal/open, get/keys/diff, password resolution order, vault format, and CI patterns. Source: github.com/anivaryam/env-vault.
---

# env-vault

Encrypted `.env` file manager. AEAD (encrypt-then-MAC) + Argon2id. Plaintext `.env` stays gitignored; `.env.vault` (encrypted, base64, single line of header + payload) is safe to commit.

Repo: `github.com/anivaryam/env-vault`. Binary: `env-vault` (install via `brokit install env-vault`, `npm install -g env-vault`, or release tarball).

## When to reach for it

- Sharing secrets across a team via the same git repo, without third-party services.
- Decrypting at build/deploy time in CI with a single `ENV_VAULT_KEY` secret.
- Reading one secret in a script without exposing the rest (`env-vault get`).
- Catching drift between local `.env` and committed `.env.vault` (`env-vault diff`).

Do NOT use for: replacing a real secrets manager at scale (AWS SM, Vault, Doppler), per-user secret access control, secret rotation workflows, or audit-logged secret access.

## CLI surface

```sh
env-vault seal [file]                   # encrypt .env → .env.vault
env-vault open [file]                   # decrypt .env.vault → .env
env-vault get <key> [file]              # single value to stdout (pipe-friendly)
env-vault keys [file]                   # list keys without values
env-vault diff [env-file] [vault-file]  # compare key sets (add --values to show changes)
```

Flags: `-o/--out` (output path), `-p/--password` (prefer not — use prompt or env var).

## Password resolution

Order:
1. `-p` / `--password` flag
2. `ENV_VAULT_KEY` environment variable
3. Interactive prompt (hidden input; seal asks twice for confirmation)

**Pick the right one for the context.** Prompt for interactive work. `ENV_VAULT_KEY` for CI. `-p` only in scripts where the password isn't sensitive in the process table (rarely the case — prefer env var).

## Quick workflows

### Initial seal

```sh
env-vault seal .env                     # prompts twice for password
git add .env.vault
echo .env >> .gitignore                 # if not already
git commit -m "add encrypted env"
```

### Open after clone

```sh
env-vault open .env.vault               # prompts for password, writes .env
```

### CI decrypt

```sh
# One secret in CI: ENV_VAULT_KEY
ENV_VAULT_KEY=$SECRET env-vault open .env.vault
# Source it for subsequent steps
set -a; . ./.env; set +a
```

Adding a new variable: edit `.env`, `env-vault seal .env`, commit `.env.vault`. No CI config changes.

### Single value in a script

```sh
DB_URL="$(env-vault get DATABASE_URL .env.vault -p "$SECRET")"
```

Output is the raw value with no trailing whitespace, so `$(...)` substitution works. Avoid `-p` in shared terminals — the password is visible in the process table.

### Diff drift

```sh
env-vault diff .env .env.vault                 # key-level summary
env-vault diff .env .env.vault --values        # show what changed; careful in shared shells
```

Use `--values` only when you intend to look at secret values — they print to stdout.

## Vault format

```
#:env-vault:v1:ruc
<base64-encoded payload>
```

Payload bytes: `salt (16) || nonce (16) || ciphertext || HMAC-SHA256 tag (32)`.

Crypto: AEAD via `random-universe-cipher` in CTR mode + HMAC-SHA256 tag. Key derivation: Argon2id (64 MB memory, 2 iterations).

Wrong password or tampered file → authentication fails → error, nothing written. The tool refuses to operate on partial output.

## .gitignore

```gitignore
# Plaintext — never commit
.env
.env.local
.env.*.local

# Encrypted vaults — safe to commit
!*.vault
```

Adjust to match your project's env file naming. The intent: plaintext gitignored, vaults always allowed.

## Common failure patterns

- **`authentication failed` on `open`** → wrong password or vault corrupted in transit. Try the password again; if still failing, restore the vault file from git history.
- **`ENV_VAULT_KEY` set but `open` still prompts** → key is empty (shell quoted empty string). Confirm `echo -n "$ENV_VAULT_KEY" | wc -c` is non-zero in the CI runner.
- **`-p` in shell history** → password leaked to `~/.bash_history` / `~/.zsh_history`. Rotate the key, re-seal.
- **Vault file looks committed but git ignores it** → `*.vault` excluded by an upstream `.gitignore`. The recommended pattern uses `!*.vault` to override.
- **Multiple env files (e.g. `.env.production`, `.env.staging`)** → seal each separately to its own vault: `env-vault seal .env.production -o .env.production.vault`. Don't mix them.
- **CI step doesn't pick up secrets after `open`** → CI shells often don't auto-load `.env`. Source it explicitly (`set -a; . ./.env; set +a`).

## Gotchas

- **No secret rotation workflow built in.** Rotate by editing `.env`, re-sealing with a new password, committing the new vault, and updating `ENV_VAULT_KEY` everywhere it's stored. Old vaults can still be opened with the old key — invalidate them by deleting from git history if needed.
- **Argon2id parameters are fixed** (64 MB, 2 iterations). Won't be slow on most machines but might be on very constrained CI runners.
- **No per-key encryption** — the whole file shares one password. Per-team access control needs a real secrets manager.
- **`diff --values` prints secrets to stdout.** Don't pipe to logs you don't trust.
- **Vault file is one base64 line.** Diff-friendly only at the file level; line-by-line diffs are meaningless.

## Verifying

```sh
env-vault seal .env -o .env.vault.tmp           # round-trip without overwriting
env-vault open .env.vault.tmp -o .env.tmp       # decrypt to tmp
diff .env .env.tmp                              # must be empty
rm .env.vault.tmp .env.tmp
env-vault keys .env.vault                       # confirms vault opens with current password
```

In CI, the canonical smoke test is `env-vault open .env.vault && test -s .env`.
