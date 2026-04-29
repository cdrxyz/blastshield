---
title: BlastShield
description: Sandbox AI coding agents with kernel-level protection against destructive cloud CLI commands.
---

## Read-Only by Default

BlastShield enforces a **default-deny** posture for all cloud CLIs. Only read operations (`list`, `describe`, `get`, `plan`) pass through automatically. Any mutating command — even `terraform apply` or `gcloud deploy` — requires biometric authentication or must be run manually by the user.

The AI agent inspects and plans. **You** execute.

## Two Layers of Defense

### Layer 1: sandbox-exec profiles

Kernel-level filesystem restrictions. The agent process physically cannot read credential files or write state files. Bypass-resistant because the kernel enforces it.

### Layer 2: command-argument guard

Touch ID / password gate for mutating subcommands. `terraform apply` prompts for authentication. `terraform plan` passes through immediately.

## Protected CLIs

| CLI | Mutating (Blocked) | Read-Only (Allowed) |
|-----|-------------------|-------------------|
| `terraform` | `apply`, `destroy`, `import`, `taint` | `init`, `plan`, `fmt`, `validate`, `show` |
| `gcloud` | `delete`, `create`, `deploy`, `update` | `list`, `describe`, `get`, `status` |
| `aws` | `delete`, `create`, `put`, `terminate` | `describe-*`, `list-*`, `get-*` |
| `az` | `delete`, `create`, `update`, `deploy` | `list`, `show`, `version` |
| `kubectl` | `apply`, `create`, `delete`, `exec` | `get`, `describe`, `logs`, `top` |
| `gh` | `delete`, `merge`, `close`, `edit` | `list`, `view`, `clone`, `fork` |
| `helm` | `install`, `upgrade`, `delete` | `list`, `status`, `show`, `search` |

## Quick Start

```bash
# Clone
git clone https://github.com/cdrxyz/blastshield.git
cd blastshield

# Add to PATH
export PATH="$PWD:$PATH"

# Run Claude Code sandboxed (read-only cloud access)
blastshield claude --dangerously-skip-permissions
```

## Composable

BlastShield works alongside existing sandbox tools — [sandvault](https://github.com/webcoyote/sandvault), [agent-safehouse](https://github.com/eugene1g/agent-safehouse), [agent-seatbelt](https://github.com/CJHwong/agent-seatbelt) — for defense in depth.

```bash
blastshield -p terraform -- safehouse claude --dangerously-skip-permissions
```
