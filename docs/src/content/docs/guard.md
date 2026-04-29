---
title: Guard
description: blastshield-guard — command-level filtering for destructive cloud CLI subcommands using Touch ID / password authentication.
---

## Overview

`blastshield-guard` provides **command-argument-level filtering** as a complement to the `sandbox-exec` profiles. While sandbox-exec operates at the file/process level and cannot filter by command arguments, blastshield-guard intercepts destructive **subcommands** and requires biometric or password authentication before allowing them.

## How It Works

```
Agent runs: terraform destroy
       │
       ▼
PATH lookup finds wrapper first
       │
       ▼
Wrapper checks: is "destroy" destructive? ─── YES
       │
       ▼
Prompt for Touch ID / sudo password
       │
  ┌────┴────┐
  │         │
Auth OK   Auth Failed
  │         │
  ▼         ▼
Execute   Block + Exit 1
```

1. **Install wrappers** — `blastshield-guard install` creates wrapper scripts for each guarded CLI
2. **PATH interception** — Prepending the guard directory to PATH ensures wrappers are found before real CLIs
3. **Pattern matching** — Each wrapper checks the subcommand against destructive patterns
4. **Authentication gate** — Destructive commands require `sudo` authentication (Touch ID or password)
5. **Pass-through** — Non-destructive commands execute immediately without any interruption

## Installation

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

| CLI | Destructive Pattern | Example Blocked Command |
|-----|-------------------|----------------------|
| `terraform` | `destroy` | `terraform destroy` |
| `gcloud` | `delete` | `gcloud compute instances delete` |
| `aws` | `delete*` | `aws s3api delete-bucket` |
| `az` | `delete` | `az group delete` |
| `kubectl` | `delete` | `kubectl delete namespace production` |
| `gh` | `delete` | `gh repo delete` |

Patterns support simple glob matching. For example, `delete*` matches `delete`, `delete-bucket`, `delete-object`, etc.

## Commands

### install

```bash
blastshield-guard install [DIR]
```

Creates wrapper scripts in the specified directory (default: the directory where blastshield-guard is located). Only wraps CLIs that are found on the system.

### uninstall

```bash
blastshield-guard uninstall [DIR]
```

Removes the wrapper scripts from the specified directory.

### list

```bash
blastshield-guard list
```

Shows all guarded CLIs and their destructive patterns:

```
Guarded CLIs and their destructive patterns:
  az: delete
  aws: delete*
  gcloud: delete
  gh: delete
  kubectl: delete
  terraform: destroy
```

### check

```bash
blastshield-guard check <cli> [args...]
```

Tests whether a specific command would be blocked or allowed. Returns exit code 1 for blocked commands, 0 for allowed.

```bash
# Check if terraform destroy would be blocked
blastshield-guard check terraform destroy
# Output: BLOCKED: terraform destroy matches destructive pattern
# Exit: 1

# Check if terraform plan would be allowed
blastshield-guard check terraform plan
# Output: ALLOWED: terraform plan
# Exit: 0
```

## Authentication

The guard uses `sudo` as its authentication mechanism:

- **Touch ID** — On MacBooks with Touch ID, `sudo` can prompt for biometric authentication
- **Password** — Falls back to your macOS user password
- **Fresh auth required** — `sudo -k` invalidates the timestamp, ensuring a fresh prompt each time

## Important Limitations

:::caution
Layer 2 (guard) is a **speed bump**, not a hard boundary. A determined agent that specifies the full path to a CLI (e.g., `/usr/local/bin/terraform destroy`) bypasses PATH wrappers.
:::

**Layer 1 (sandbox) is the hard boundary.** It blocks credential access regardless of how the CLI is invoked. Use both layers together for defense in depth.

### Best Practices

1. **Always use with Layer 1** — The guard alone is not sufficient; always run agents inside `blastshield` sandbox-exec profiles
2. **Prepend to PATH early** — Set the guard directory first in PATH so wrappers take priority
3. **Consider the threat model** — The guard stops accidental and casual misuse; a highly capable agent may find ways around it
4. **Layer 1 is your safety net** — Even if an agent bypasses the guard, it still cannot read credentials (blocked by sandbox)
