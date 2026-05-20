# claude-plugins

Claude Code plugins for the [anivaryam](https://github.com/anivaryam) tool family. One marketplace, four plugins — each bundling a skill, slash commands, a SessionStart hook, and a diagnostic subagent.

## Plugins

| Plugin | What it covers | Upstream |
|--------|---------------|----------|
| **proc-compose** | Local process orchestrator. Dev stacks, microservices, container entrypoints. | [proc-compose](https://github.com/anivaryam/proc-compose) |
| **merge-port** | Local reverse proxy. Frontend + backend on one port. | [merge-port](https://github.com/anivaryam/merge-port) |
| **tunnel** | Self-hosted ngrok alternative. HTTP/TCP/UDP, named tunnels, daemon mode. | [tunnel](https://github.com/anivaryam/tunnel) |
| **env-vault** | Encrypted `.env` files (AEAD + Argon2id). | [env-vault](https://github.com/anivaryam/env-vault) |

Each plugin is independent — install only the ones you need.

## Install

Two steps. The marketplace must be added before any plugin can be installed.

**Step 1 — add the marketplace:**

```
/plugin marketplace add anivaryam/claude-plugins
```

**Step 2 — install one or more plugins:**

```
/plugin install proc-compose@claude-plugins
/plugin install merge-port@claude-plugins
/plugin install tunnel@claude-plugins
/plugin install env-vault@claude-plugins
```

The `@claude-plugins` suffix names the marketplace. Skip it only if you're sure no other marketplace exposes a plugin with the same name.

Verify the marketplace was added:

```
/plugin marketplace list
```

If `/plugin install proc-compose` returns `Plugin "proc-compose" not found in any marketplace`, you skipped step 1.

## What each plugin gives you

- **Skill** — usage knowledge loaded into context when the tool is relevant. Covers config, lifecycle, gotchas, verification.
- **Slash commands** — `/proc-compose:up`, `/merge-port:up`, `/tunnel:http`, `/env-vault:seal`, etc. Pre-flight checks before running the underlying CLI.
- **SessionStart hook** — detects config files (`proc-compose.yml`, `.merge-port.yaml`, `~/.tunnel/config.yml`, `*.vault`) in the cwd and surfaces a brief context note.
- **Subagent** — `proc-compose-doctor`, `merge-port-doctor`, `tunnel-doctor`, `env-vault-doctor`. Invoke for diagnosis when something is wrong.

## Installing the binaries

Plugins ship the skill, commands, hook, and subagent — not the binaries themselves. Each plugin exposes an `/install` slash command that fetches the latest release:

```
/proc-compose:install
/merge-port:install
/tunnel:install
/env-vault:install
```

Resolution order inside each `install`:
1. `brokit install <tool>` if [brokit](https://github.com/anivaryam/brokit) is on PATH (recommended — one command for install, update, uninstall across the whole tool family).
2. Upstream `install.sh` from the tool's repo (verifies sha256 where applicable, drops the binary into `~/.local/bin`). `env-vault` additionally tries `npm install -g env-vault` before falling back to a platform-matched release tarball.

The SessionStart hook in each plugin also detects relevant config files (e.g. `proc-compose.yml`) and nudges you to run the install command when the binary is missing.

To install everything in one go at the shell level:

```sh
brokit install proc-compose merge-port tunnel env-vault
```

## Layout

```
claude-plugins/
├── .claude-plugin/marketplace.json
└── plugins/
    ├── proc-compose/
    │   ├── .claude-plugin/plugin.json
    │   ├── skills/proc-compose/SKILL.md
    │   ├── commands/{up,bootstrap,status,doctor}.md
    │   ├── hooks/detect-config.sh
    │   └── agents/proc-compose-doctor.md
    ├── merge-port/
    │   ├── .claude-plugin/plugin.json
    │   ├── skills/merge-port/SKILL.md
    │   ├── commands/{up,discover,validate}.md
    │   ├── hooks/detect-config.sh
    │   └── agents/merge-port-doctor.md
    ├── tunnel/
    │   ├── .claude-plugin/plugin.json
    │   ├── skills/tunnel/SKILL.md
    │   ├── commands/{http,doctor,list}.md
    │   ├── hooks/detect-config.sh
    │   └── agents/tunnel-doctor.md
    └── env-vault/
        ├── .claude-plugin/plugin.json
        ├── skills/env-vault/SKILL.md
        ├── commands/{seal,open,diff}.md
        ├── hooks/detect-config.sh
        └── agents/env-vault-doctor.md
```

## Contributing

Per-plugin changes only:
- **Skill behaviour** — edit `plugins/<name>/skills/<name>/SKILL.md`.
- **Slash commands** — edit/add `plugins/<name>/commands/*.md`.
- **Hooks** — edit `plugins/<name>/hooks/*.sh` and the manifest at `plugins/<name>/.claude-plugin/plugin.json`.
- **Subagents** — edit `plugins/<name>/agents/*.md`.

Skill style: drop articles, fragments OK in headings, but full sentences in the body so non-native readers can pick it up cold. Code blocks unchanged. The plugins are independent — don't cross-reference internal state.

## License

MIT.
