---
title: BlastShield
description: Sandbox AI coding agents with kernel-level protection against destructive cloud CLI commands.
template: splash
hero:
  tagline: Shrink the blast radius of your agentic engineering.
  actions:
    - text: Get Started
      link: ./getting-started/
      icon: right-arrow
    - text: GitHub
      link: https://github.com/cdrxyz/blastshield
      icon: external
---

## Read-Only by Default

BlastShield enforces a default-deny posture for cloud CLIs and package managers. Read operations such as `list`, `describe`, `get`, and `plan` pass through automatically. Mutating commands such as `terraform apply`, `gcloud deploy`, `npm install`, and `pip install` are blocked or forced back to the user.

The agent inspects and plans. You execute.

## Two Layers of Defense

### Layer 1: sandbox-exec profiles

Kernel-level filesystem restrictions keep agents away from credential files, state, and protected paths.

### Layer 2: command-argument guard

Runtime guard wrappers intercept dangerous subcommands before they reach Terraform, gcloud, kubectl, npm, pip, and other CLIs.

## Quick Start

```bash
brew install cdrxyz/tap/blastshield
blastshield claude --dangerously-skip-permissions
```

For manual installation, see [Getting Started](./getting-started/).
