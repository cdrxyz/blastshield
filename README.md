# BlastShield 🔒

> [!WARNING]
> BlastShield is still in beta and may contain bugs. Validate it in a non-production environment before depending on it for safety-critical workflows.

**Sandbox AI coding agents with kernel-level protection against destructive cloud CLI commands.**

![BlastShield](docs/public/blastshield-demo.png)

Uses macOS `sandbox-exec` (Apple Seatbelt) to enforce filesystem restrictions that prevent AI agents from executing destructive operations — `terraform destroy`, `gcloud compute instances delete`, `aws s3 rb`, `az group delete`, `kubectl delete namespace` — even when running with `--dangerously-skip-permissions` or equivalent unrestricted modes.

## Installation

### Homebrew (recommended)

```bash
brew install cdrxyz/tap/blastshield
```

### Advanced: Manual Installation

```bash
git clone https://github.com/cdrxyz/blastshield.git
cd blastshield
export PATH="$PWD:$PATH"
```

## Quick Start

```bash
# Run Claude Code sandboxed
blastshield claude --dangerously-skip-permissions

# Run Codex sandboxed
blastshield codex --full-auto

# Run OpenCode sandboxed
blastshield opencode
```

## Documentation

Full documentation is available at **[cdrxyz.github.io/blastshield](https://cdrxyz.github.io/blastshield)**:

- **[Getting Started](https://cdrxyz.github.io/blastshield/getting-started)** — installation, first run, configuration
- **[Architecture](https://cdrxyz.github.io/blastshield/architecture)** — two-layer defense model, how sandbox-exec and guard work together
- **[Profiles](https://cdrxyz.github.io/blastshield/profiles)** — built-in and custom SBPL profiles, auto-detection
- **[Guard](https://cdrxyz.github.io/blastshield/guard)** — command-argument filtering, Touch ID prompts, install/uninstall
- **[Layering](https://cdrxyz.github.io/blastshield/layering)** — composing BlastShield with sandvault, safehouse, and other tools
- **[Whitepaper](https://cdrxyz.github.io/blastshield/whitepaper)** — formal write-up with PDF download
- **[FAQ](https://cdrxyz.github.io/blastshield/faq)** — common questions, caveats, and troubleshooting

## Blog

Read [Shrink the Blast Radius](https://cdr.xyz/blog/shrink-the-blast-radius) — why BlastShield exists and why your AI agent has no chill.

## License

Apache License 2.0
