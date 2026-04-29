---
title: BlastShield
description: Sandbox AI coding agents with kernel-level protection against destructive cloud CLI commands.
---

## Two Layers of Defense

### Layer 1: sandbox-exec profiles

Kernel-level filesystem restrictions. The agent process physically cannot read credential files or write state files. Bypass-resistant because the kernel enforces it.

### Layer 2: command-argument guard

Touch ID / password gate for destructive subcommands. `terraform destroy` prompts for authentication. `terraform plan` passes through immediately.

## Protected CLIs

| CLI | Blocked Operations |
|-----|-------------------|
| `terraform` | `destroy` |
| `gcloud` | `delete` |
| `aws` | `delete*` |
| `az` | `delete` |
| `kubectl` | `delete` |
| `gh` | `delete` |

## Quick Start

```bash
# Clone
git clone https://github.com/cdrxyz/blastshield.git
cd blastshield

# Add to PATH
export PATH="$PWD:$PATH"

# Run Claude Code sandboxed
blastshield claude --dangerously-skip-permissions
```

## Composable

BlastShield works alongside existing sandbox tools — [sandvault](https://github.com/webcoyote/sandvault), [agent-safehouse](https://github.com/eugene1g/agent-safehouse), [agent-seatbelt](https://github.com/CJHwong/agent-seatbelt) — for defense in depth.

```bash
blastshield -p terraform -- safehouse claude --dangerously-skip-permissions
```
