---
title: Guard
description: blastshield-guard — command-level filtering that blocks mutating cloud CLI subcommands.
---

## Overview

`blastshield-guard` provides **command-argument-level filtering** as a complement to the `sandbox-exec` profiles. While sandbox-exec operates at the file/process level and cannot filter by command arguments, blastshield-guard intercepts **mutating subcommands** before they reach tools such as Terraform, gcloud, kubectl, and gh.

When you launch an agent with `blastshield`, temporary runtime wrappers are injected automatically and mutating commands are hard-blocked. Persistent wrappers installed for regular shell use still prompt for Touch ID or your sudo password.

**Philosophy: read-only by default.** Any subcommand that isn't explicitly read-only is treated as mutating and requires authentication.

## How It Works

```
Agent runs: terraform apply
       │
       ▼
PATH lookup finds wrapper first
       │
       ▼
Wrapper checks: is "apply" read-only? ─── NO
       │
       ▼
Runtime guard blocks command
       │
       ▼
Exit 1; run it yourself outside the agent sandbox
```

1. **Runtime wrappers** — `blastshield` creates temporary wrappers for guarded CLIs found on your current PATH
2. **PATH interception** — The temporary guard directory is prepended to PATH before the sandboxed command starts
3. **Read-only check** — Each wrapper checks if the subcommand is in the read-only allowlist
4. **Default deny** — If the subcommand isn't read-only, it is treated as mutating
5. **Runtime block** — Inside `blastshield`, mutating commands exit with a clear block message
6. **Pass-through** — Read-only commands execute immediately without any interruption

## Installation

No installation is required for the runtime guard. `blastshield` enables it automatically:

```bash
blastshield claude
blastshield codex --dangerously-bypass-approvals-and-sandbox
```

Disable automatic guard injection when you explicitly need raw PATH behavior:

```bash
blastshield --no-guard claude
```

You can also install persistent wrappers for regular shell use outside BlastShield:

```bash
# Install to default location (~/.blastshield/guard)
blastshield-guard install

# Install to custom location
blastshield-guard install ~/bin/guard
```

Then add the guard directory to your PATH **before** the real CLI paths:

```bash
export PATH="$HOME/.blastshield/guard:$PATH"
```

For AI agents, add this to their environment configuration.

## Guarded CLIs

### terraform

| Read-Only (auto-allow) | Mutating (requires auth) |
|------------------------|-------------------------|
| `init`, `plan`, `fmt`, `validate` | `apply`, `destroy` |
| `show`, `output`, `console` | `import`, `taint`, `untaint`, `refresh` |
| `state list`, `state show` | `state rm`, `state mv` |
| `workspace list`, `workspace select` | `workspace delete`, `workspace new` |
| `providers`, `version`, `graph` | |

### gcloud

| Read-Only (auto-allow) | Mutating (requires auth) |
|------------------------|-------------------------|
| `list`, `describe`, `get` | `delete`, `create`, `deploy`, `update` |
| `auth`, `status`, `version` | `add`, `remove`, `patch`, `set`, `reset` |
| `config`, `help` | `restart`, `resize`, `enable`, `disable` |
| | `submit`, `cancel` |

### aws

| Read-Only (auto-allow) | Mutating (requires auth) |
|------------------------|-------------------------|
| `describe-*`, `list-*`, `get-*` | `delete`, `create`, `put`, `update` |
| `head-*`, `wait` | `deploy`, `terminate`, `run-*` |
| `s3 ls`, `s3 cp` (download), `s3 presign` | `start-*`, `stop-*`, `reboot` |
| `sts get-caller-identity` | `authorize`, `revoke`, `send`, `cancel` |
| `logs describe-*`, `logs get-*` | |
| `dynamodb scan/query/get-item` | |
| `iam list-*/get-*` | |

### az (Azure)

| Read-Only (auto-allow) | Mutating (requires auth) |
|------------------------|-------------------------|
| `list`, `show` | `delete`, `create`, `update`, `deploy` |
| `account show/list` | `set`, `remove`, `add`, `lock`, `unlock` |
| `version`, `help` | `scale`, `restart` |

### kubectl

| Read-Only (auto-allow) | Mutating (requires auth) |
|------------------------|-------------------------|
| `get`, `describe`, `logs` | `apply`, `create`, `delete`, `patch` |
| `top`, `events` | `scale`, `taint`, `exec` |
| `api-resources`, `api-versions`, `explain` | `cordon`, `uncordon`, `drain` |
| `auth can-i` | `rollout restart`, `rollout undo` |
| `config view`, `config get-contexts` | `label`, `annotate`, `set` |
| `rollout status`, `rollout history` | `expose`, `run`, `cp`, `debug` |
| `version` | |

### gh (GitHub CLI)

| Read-Only (auto-allow) | Mutating (requires auth) |
|------------------------|-------------------------|
| `repo list/view/clone/fork` | `repo delete/edit/rename` |
| `pr list/view/diff/checkout` | `pr merge/close` |
| `issue list/view` | `issue close` |
| `release list/view/download` | `release delete` |
| `workflow list/view` | `workflow disable/enable` |
| `auth status` | `run cancel` |
| | `api -X DELETE/PUT/PATCH` |

### helm

| Read-Only (auto-allow) | Mutating (requires auth) |
|------------------------|-------------------------|
| `list`, `status`, `history` | `install`, `upgrade` |
| `show`, `search` | `delete`, `uninstall`, `rollback` |
| `version`, `repo list/update` | `push` |

## Commands

### install

```bash
blastshield-guard install [DIR]
```

Creates wrapper scripts in the specified directory. Only wraps CLIs that are found on the system.

### uninstall

```bash
blastshield-guard uninstall [DIR]
```

Removes the wrapper scripts from the specified directory.

### list

```bash
blastshield-guard list
```

Shows all guarded CLIs with their read-only and mutating patterns.

### check

```bash
blastshield-guard check <cli> [args...]
```

Tests whether a specific command would be allowed or blocked:

```bash
# Check if terraform apply would be blocked
blastshield-guard check terraform apply
# Output: BLOCKED (mutating — requires auth): terraform apply
# Exit: 1

# Check if terraform plan would be allowed
blastshield-guard check terraform plan
# Output: ALLOWED (read-only): terraform plan
# Exit: 0
```

## Runtime vs Persistent Behavior

Runtime wrappers created by `blastshield` do not prompt for authentication. Mutating commands are blocked and must be run by you outside the agent sandbox.

Persistent wrappers installed with `blastshield-guard install` use `sudo` as their authentication mechanism:

- **Touch ID** — On MacBooks with Touch ID, `sudo` can prompt for biometric authentication
- **Password** — Falls back to your macOS user password
- **Fresh auth required** — `sudo -k` invalidates the timestamp, ensuring a fresh prompt each time

## Important Limitations

:::caution
Layer 2 (guard) is a **speed bump**, not a hard boundary. A determined agent that specifies the full path to a CLI (e.g., `/usr/local/bin/terraform apply` or `./bin/terraform apply`) bypasses PATH wrappers.
:::

Automatic runtime guards cover repo-local and Hermit shims when the command is resolved through PATH, such as `terraform apply` with `./bin` already on PATH. Direct path execution bypasses argument filtering.

**Layer 1 (sandbox) is the hard boundary.** It blocks credential access regardless of how the CLI is invoked. Use both layers together for defense in depth.

### Best Practices

1. **Always use with Layer 1** — The guard alone is not sufficient; always run agents inside `blastshield` sandbox-exec profiles
2. **Invoke tools by command name** — Runtime guards cover commands resolved through PATH, including Hermit shims
3. **Default deny** — Any subcommand not in the read-only list is treated as mutating. Add new read-only patterns cautiously.
4. **Layer 1 is your safety net** — Even if an agent bypasses the guard, it still cannot read credentials (blocked by sandbox)
