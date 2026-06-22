---
title: Architecture
description: The three-layer defense architecture behind BlastShield — from kernel-level sandboxing to command-argument filtering.
---

## Three-Layer Defense

BlastShield provides defense in depth through three complementary layers, each handling what the layer above cannot.

```
┌─────────────────────────────────────────────────┐
│                  AI Agent                        │
│  (Claude Code, Codex, Conductor, Cursor, etc.)  │
└──────────────────┬──────────────────────────────┘
                   │
    ┌──────────────┼──────────────────┐
    │              ▼                   │
    │  Layer 2: blastshield-guard      │
    │  (command-argument filter)       │
    │  • Intercepts destructive        │
    │    subcommands via PATH wrappers │
    │  • Requires Touch ID / password  │
    │  • Passes safe commands through  │
    └──────────────┬──────────────────┘
                   │
    ┌──────────────┼──────────────────┐
    │              ▼                   │
    │  Layer 1: blastshield            │
    │  (sandbox-exec profiles)         │
    │  • Kernel-enforced file policy   │
    │  • Blocks credential reads       │
    │  • Blocks state file writes      │
    │  • Protects backend configs      │
    └──────────────┬──────────────────┘
                   │
    ┌──────────────┼──────────────────┐
    │              ▼                   │
    │  Layer 0: agent's built-in       │
    │  sandbox (Claude /sandbox,       │
    │  Codex approval policies)        │
    │  • Tool-level gating             │
    │  • Network filtering             │
    └──────────────┬──────────────────┘
                   │
                   ▼
              macOS Kernel
```

## Layer 0: Agent's Built-in Sandbox

The agent itself may provide a sandbox (e.g. Claude's `/sandbox`, Codex's approval policies). These operate at the **tool level** — they gate the agent's own tools and network access.

**Limitation:** These only gate their own tools. An agent that shells out via Bash or Python bypasses all of it. A determined agent can simply run a subprocess that the agent sandbox never sees.

## Layer 1: blastshield — Kernel-Level Sandbox

This is the hard boundary. BlastShield uses macOS `sandbox-exec` (Apple Seatbelt) to enforce **filesystem and process restrictions at the kernel level**. The kernel doesn't care what the agent thinks it's allowed to do.

### How It Works

1. **Profile Assembly** — BlastShield combines multiple SBPL (Seatbelt Profile Language) profiles into a single policy
2. **Deny-by-default** — The assembled profile starts with `(deny default)`, then adds only necessary allow rules
3. **Profile intersection** — Every deny rule from every loaded profile is enforced; profiles compose by intersection
4. **Kernel enforcement** — `sandbox-exec -f <profile> -- <command>` runs the agent process inside the sandbox

### What It Blocks

- **Credential file reads** — The agent process physically cannot read `~/.aws/credentials`, `~/.azure/`, GCP service account keys, etc.
- **State file writes** — Cannot modify Terraform state, Helm chart locks, or backend configurations
- **Global package directory writes** — Cannot write to Homebrew Cellar, npm global `node_modules`, pip global site-packages, gem directories, Cargo registry, Hermit packages, or apt/dnf package caches
- **Lockfile writes** — Cannot modify `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`, `Pipfile.lock`, `Gemfile.lock`, or `Cargo.lock`
- **Protected path access** — Each profile defines its own set of protected paths

### What It Cannot Block

`sandbox-exec` operates at the file/process level. It **cannot filter by command arguments**. It cannot distinguish `terraform destroy` from `terraform plan` — both execute the same `terraform` binary. That's where Layer 2 comes in.

## Layer 2: blastshield-guard — Command-Argument Filter

This layer handles what `sandbox-exec` cannot see: **which subcommands the agent invokes**.

### How It Works

1. **PATH wrappers** — `blastshield` automatically creates temporary wrapper scripts for each guarded CLI found on PATH
2. **Intercept** — When the agent runs `terraform destroy`, the wrapper (found first on PATH) intercepts it
3. **Block** — Destructive subcommands are blocked inside the agent sandbox
4. **Pass-through** — Non-destructive commands execute immediately without interruption

### Guarded Commands

| CLI | Destructive Pattern |
|-----|-------------------|
| `terraform` | `destroy` |
| `gcloud` | `delete` |
| `aws` | `delete*` |
| `az` | `delete` |
| `kubectl` | `delete` |
| `gh` | `delete` |
| `npm` | `install`, `ci`, `add`, `remove` |
| `pip` | `install` |
| `brew` | `install`, `uninstall`, `upgrade` |
| `yarn` | `add`, `remove`, `install` |
| `pnpm` | `add`, `remove`, `install` |
| `gem` | `install`, `uninstall`, `update` |
| `cargo` | `add`, `install`, `rm` |
| `hermit` | `install`, `uninstall` |
| `apt` | `install`, `remove`, `purge` |
| `dnf` | `install`, `remove`, `upgrade` |

### Important Note

Layer 2 is a **speed bump**, not a hard boundary. A determined agent that specifies the full path to a CLI (e.g. `/usr/local/bin/terraform destroy` or `./bin/terraform destroy`) bypasses PATH wrappers. Runtime wrappers cover Hermit and repo-local shims when they are invoked by command name. **Layer 1 (sandbox) is the hard boundary** — it blocks credential access regardless of how the CLI is invoked.

## Why Both Layers?

| Scenario | Layer 1 (sandbox) | Layer 2 (guard) |
|----------|:-:|:-:|
| Agent reads `~/.aws/credentials` directly | ✅ Blocked | ❌ Not visible |
| Agent runs `terraform destroy` | ❌ Same binary as `terraform plan` | ✅ Intercepted |
| Agent uses full path `/usr/local/bin/terraform destroy` | ❌ Same binary | ❌ Bypassed |
| Agent runs `aws s3 rb` with already-loaded credentials | ❌ Creds already in env | ✅ Intercepted |
| Agent exfiltrates secrets via network | ⚠️ Only if `-c` used | ❌ Not visible |
| Agent runs `npm install` into global node_modules | ✅ Write denied | ✅ Intercepted |
| Agent runs `pip install` into project venv | ❌ Project writes allowed | ✅ Intercepted |
| Agent writes `package-lock.json` directly | ✅ Write denied | ❌ Not a CLI invocation |

The layers are complementary — neither is sufficient alone. Use both for defense in depth.
