---
title: Getting Started
description: Quick start guide for BlastShield — sandbox AI coding agents with kernel-level protection against destructive cloud CLI commands.
---

## Quick Start

### Prerequisites

- macOS (uses `sandbox-exec` / Apple Seatbelt)
- Cloud CLIs you want to protect (terraform, gcloud, aws, az, kubectl, gh)

### Install

```bash
# Clone
git clone https://github.com/cdrxyz/blastshield.git
cd blastshield

# Add to PATH
export PATH="$PWD:$PATH"
```

### Run an Agent with Protection

```bash
# Run Claude Code with all auto-detected cloud protections
blastshield claude --dangerously-skip-permissions

# Run Codex with full auto-approve
blastshield codex --full-auto

# Run OpenCode with auto-detected profiles
blastshield opencode

# Run any command
blastshield -p kubectl bash
```

### Install Command-Level Guards

BlastShield automatically injects temporary guard wrappers ahead of your current `PATH` when launching an agent. This catches globally installed CLIs and repo-local/Hermit shims that are resolved by command name, hard-blocking mutating subcommands such as `terraform apply` inside the agent sandbox.

To disable automatic guard injection:

```bash
blastshield --no-guard claude
```

You can also install persistent guard wrappers for regular shell use outside BlastShield:

```bash
# Install guard wrappers
blastshield-guard install

# Add to PATH (before real CLIs)
export PATH="$HOME/.blastshield/guard:$PATH"
```

Persistent wrappers prompt for Touch ID or your sudo password. Runtime wrappers inside `blastshield` hard-block mutating commands and ask you to run them yourself outside the agent sandbox.

### Check Status

```bash
# Show detected CLIs and auto-detected profiles
blastshield --status

# Show recent sandbox violations from system log
blastshield --violations
```

## Basic Usage

### Auto-Detection

BlastShield scans your project directory for indicator files and automatically loads the right profiles:

| Profile | Triggers |
|---------|----------|
| `terraform` | `*.tf` files |
| `gcloud` | `.gcloudignore`, `cloudbuild.yaml`, `app.yaml` |
| `aws` | `serverless.yml`, `template.yaml`, `cdk.json`, `samconfig.toml` |
| `azure` | `azure-pipelines.yml`, `local.settings.json` |
| `kubectl` | `kustomization.yaml`, `Chart.yaml`, `skaffold.yaml` |
| `gh` | `.github/` directory |

### Explicit Profiles

```bash
# Specify profiles manually
blastshield -p terraform codex
blastshield -p gcloud -p aws opencode

# Disable auto-detection
blastshield --no-detect claude
blastshield --no-detect codex
blastshield --no-detect opencode
```

### Clean Environment

Strip API keys and secrets from environment variables before launching the agent:

```bash
blastshield -c claude --dangerously-skip-permissions
blastshield -c codex --full-auto
blastshield -c opencode
```

### Diagnostics

```bash
# Show detected CLIs and auto-detected profiles
blastshield --status

# Show recent sandbox violations from system log
blastshield --violations
```

## Next Steps

- Learn about the [three-layer defense architecture](/architecture/)
- Explore all [built-in profiles](/profiles/)
- Set up [blastshield-guard](/guard/) for command-level filtering
- Compose BlastShield with [other sandbox tools](/layering/)
