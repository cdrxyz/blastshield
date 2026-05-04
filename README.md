# BlastShield 🔒

**Sandbox AI coding agents with kernel-level protection against destructive cloud CLI commands.**

Uses macOS `sandbox-exec` (Apple Seatbelt) to enforce filesystem restrictions that prevent AI agents from executing destructive operations — `terraform destroy`, `gcloud compute instances delete`, `aws s3 rb`, `az group delete`, `kubectl delete namespace` — even when running with `--dangerously-skip-permissions` or equivalent unrestricted modes.

## Quick Start

```bash
git clone https://github.com/cdrxyz/blastshield.git
cd blastshield
export PATH="$PWD:$PATH"

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

## Caveats

- **macOS only.** `sandbox-exec` is Apple-specific. For Linux, use [bubblewrap](https://github.com/containers/bubblewrap).
- **sandbox-exec is deprecated** by Apple (since 10.15). Still works on Sequoia. No replacement exists for ad-hoc CLI sandboxing.
- **Network is open by default.** See [architecture docs](https://cdrxyz.github.io/blastshield/architecture) for mitigation with `-c`.
- **Layer 2 (guard) is a speed bump**, not a hard boundary. Layer 1 (sandbox) is the hard boundary.

## License

Apache License 2.0
