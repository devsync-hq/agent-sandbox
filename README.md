# Agent Sandbox

A lightweight OS-level sandbox launcher for AI coding agents. Supports Claude Code and Gemini CLI; select the agent with the `AGENT` env var.

Runs the agent with filesystem and network isolation using the agent's built-in bubblewrap (Linux/WSL2) or Seatbelt (macOS) sandbox. No Docker required.

## Supported Agents

| Agent | CLI | `AGENT` value | Launch flag | Prerequisites (Linux/WSL2) |
|-------|-----|---------------|-------------|---------------------------|
| [Claude Code](https://claude.ai/code) | `claude` | `claude` (default) | `--dangerously-skip-permissions` | `sudo apt-get install bubblewrap socat` |
| [Gemini CLI](https://github.com/google-gemini/gemini-cli) | `gemini` | `gemini` | `--yolo` | `sudo apt-get install bubblewrap socat` |

## Architecture

```
[Agent CLI — HOST, --dangerously-skip-permissions]
  ├─ API calls          → allowed (managed domain)
  ├─ Bash filesystem ops → restricted to $WORKSPACE (OS-level, bubblewrap on WSL2)
  ├─ Bash network calls  → blocked except managed API domains
  ├─ WebSearch/WebFetch  → blocked (allowManagedDomainsOnly covers native tools too)
  └─ Native Write/Edit   → scoped to workspace (sandbox.filesystem.allowWrite)
```

## Prerequisites

**Linux / WSL2:**
```bash
sudo apt-get install bubblewrap socat
```

**macOS:** Works out of the box — Claude Code uses macOS Seatbelt automatically.

## Usage

```bash
# Claude Code (default) — current directory
./run.sh

# Claude Code — specific workspace
./run.sh /path/to/workspace

# Gemini CLI — current directory
AGENT=gemini ./run.sh

# Gemini CLI — specific workspace
AGENT=gemini ./run.sh /path/to/workspace
```

For Claude, `run.sh` injects the sandbox config into `.claude/settings.local.json` in your workspace for the duration of the session; the file is restored (or removed) automatically on exit. For Gemini, no settings file is managed — the Gemini CLI handles its own sandbox configuration.

## What IS sandboxed

| Boundary | Enforcement |
|----------|-------------|
| Bash filesystem writes outside workspace | Blocked at OS level (bubblewrap / Seatbelt) |
| Outbound network except managed API domains | Blocked via `allowManagedDomainsOnly: true` |
| WebSearch / WebFetch tools | Blocked (same network isolation applies) |
| Subprocesses (npm, git, kubectl, curl, etc.) | Inherit sandbox boundaries — no escape |
| Per-command sandbox bypass | Disabled (`allowUnsandboxedCommands: false`) |

## What is NOT sandboxed

| Gap | Notes |
|-----|-------|
| Agent's native **Read** tool | No `allowRead` allowlist exists in the sandbox API; mitigated by `denyRead` list below |
| Anthropic API | Explicitly allowed — required for the agent to function |

## denyRead list

The following paths are blocked from the agent's native Read tool:

`~/.ssh`, `~/.gnupg`, `~/.aws`, `~/.azure`, `~/.gcloud`, `~/.kube`, `~/.docker`, `~/.config`, `~/.netrc`, `~/.npmrc`, `~/.pypirc`, `/etc/shadow`, `/etc/sudoers`, `/root`

**Limitation:** `denyRead` is a blocklist, not an allowlist. Paths outside the workspace that are not on this list remain readable by the agent's native tools.

## How network isolation works

A proxy runs outside the sandbox and intercepts all outbound traffic from every subprocess, script, and native agent tool (WebSearch, WebFetch, npm, git, curl, etc.). `allowManagedDomainsOnly: true` routes all non-Anthropic requests to a block response. This is enforced at the OS network layer, not just for Bash commands.

## How it works

1. `run.sh` resolves the workspace path and reads `AGENT` (default: `claude`).
2. On Linux, verifies `bwrap` is installed — exits with install instructions if not.
3. **Claude only:** backs up (or notes absence of) `.claude/settings.local.json`; merges the `sandbox` key from `sandbox-settings.json` into it; registers an `EXIT` trap to restore the file.
4. Launches the agent: `claude --dangerously-skip-permissions` or `gemini --yolo`.

## Making sandbox settings permanent

To apply the sandbox settings globally (all Claude Code sessions), paste the contents of `sandbox-settings.json` into your `~/.claude/settings.json`:

```json
{
  "sandbox": {
    "enabled": true,
    "allowManagedDomainsOnly": true,
    "allowUnsandboxedCommands": false,
    "filesystem": {
      "allowWrite": ["./"],
      "denyRead": [
        "~/.ssh", "~/.gnupg", "~/.aws", "~/.azure",
        "~/.gcloud", "~/.kube", "~/.docker", "~/.config",
        "~/.netrc", "~/.npmrc", "~/.pypirc",
        "//etc/shadow", "//etc/sudoers", "//root"
      ]
    }
  }
}
```

## Key settings explained

| Setting | Value | Effect |
|---------|-------|--------|
| `sandbox.enabled` | `true` | Activates OS-level sandbox for all Bash commands |
| `allowManagedDomainsOnly` | `true` | Blocks all network except Anthropic-managed endpoints |
| `allowUnsandboxedCommands` | `false` | Removes per-command sandbox escape hatch |
| `filesystem.allowWrite` | `["./"]` | Restricts writes to the workspace root (resolved from settings file location) |
| `filesystem.denyRead` | list | Blocks the agent's native Read tool from credential store paths |

## Monorepo / Contributing

This repo is maintained as a git subtree inside [devsync-hq](https://github.com/devsync-hq/devsync-hq) at `services/agent-sandbox/`. Changes are made there and pushed here via:

```bash
./services/agent-sandbox/push.sh
```

To contribute directly: open a PR against this repo as normal. Changes will be pulled back into the monorepo via `git subtree pull`.
