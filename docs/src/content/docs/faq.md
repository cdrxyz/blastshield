---
title: FAQ
description: Common questions about BlastShield — sandbox-exec deprecation, Linux alternatives, network access, and more.
---

## General

### What is BlastShield?

BlastShield is a macOS tool that wraps AI coding agents and GUI launchers (Claude Code, Codex, Grok Build, Conductor, Cursor, Gemini) in `sandbox-exec` profiles to protect against destructive cloud CLI commands. It provides two layers of defense: kernel-level filesystem sandboxing and command-argument filtering with biometric/password authentication.

### Why do I need this? My agent has a built-in sandbox.

Built-in agent sandboxes (Claude's `/sandbox`, Codex's approval policies) only gate their own tools. An agent that shells out via Bash or Python bypasses all of it. OS-level enforcement can't be bypassed — the kernel doesn't care what the agent thinks it's allowed to do.

### Which AI agents does BlastShield support?

Any command-line tool. BlastShield doesn't need to know about the agent — it wraps any process in a sandbox. Commonly used with:
- Claude Code (`blastshield claude`)
- OpenAI Codex (`blastshield codex`)
- Grok Build (`blastshield grok` or `blastshield grok --always-approve`)
- OpenCode (`blastshield opencode`)
- Conductor (`blastshield -p gui-app open /Applications/Conductor.app`)
- Cursor (`blastshield cursor`)
- Google Gemini (`blastshield gemini`)
- Any other CLI tool (`blastshield bash`)

Grok Build has first-class runtime-state support in the base profile: sessions, memory, logs, and auto-update binaries under `~/.grok` can write, while auth, config, skills, plugins, and hooks stay protected. BlastShield also has first-class support for Conductor as a macOS GUI app. See the [Conductor guide](../conductor/) for the launch command and workspace write policy.

### How do I run Grok Build under BlastShield?

```bash
# Interactive / YOLO-style tool approval
blastshield grok --always-approve

# Headless one-shot
blastshield grok -p "Summarize this repo"

# With explicit cloud profiles
blastshield -p terraform -p gh grok --always-approve
```

Authenticate Grok **outside** BlastShield first (`grok login`) or use `XAI_API_KEY`. BlastShield intentionally blocks writes to `~/.grok/auth.json` and `~/.grok/config.toml` so a sandboxed agent cannot replace credentials, policy, skills, plugins, or hooks. Session history, memory, logs, sockets, and auto-update binaries under `~/.grok` remain writable so normal Grok workflows work.

If token refresh fails because `auth.json` is write-protected, set `XAI_API_KEY` or re-login outside the sandbox, then relaunch with BlastShield.


## sandbox-exec & macOS

### Is sandbox-exec deprecated?

Yes. Apple deprecated `sandbox-exec` (the command-line interface to the Seatbelt framework) in macOS 10.15 Catalina. However:

- **It still works** on macOS Sequoia (15.x) as of 2025
- **No replacement exists** for ad-hoc CLI sandboxing
- Apple's deprecation was about the public API, not the underlying framework (which Apple still uses internally)
- The Seatbelt profile language (SBPL) remains functional

BlastShield will continue to work as long as Apple maintains the `sandbox-exec` binary.

### What if Apple removes sandbox-exec entirely?

If Apple removes `sandbox-exec`, there is currently no equivalent replacement for ad-hoc CLI sandboxing on macOS. Possible alternatives at that point:

- **Entitlement-based sandboxing** — Requires code signing and an Apple Developer account; not suitable for CLI tools
- **Containerization** — Docker or Podman, but these have different threat models and significant overhead
- **Virtualization** — Run agents in VMs, but this is heavyweight and changes the workflow significantly

For now, `sandbox-exec` remains the best option for macOS CLI sandboxing.

### Can I use BlastShield on Linux?

No. `sandbox-exec` is Apple-specific and does not exist on Linux.

For Linux, consider:
- **[bubblewrap](https://github.com/containers/bubblewrap)** — Lightweight namespace-based sandboxing (similar capabilities to sandbox-exec)
- **Firejail** — Another Linux sandbox tool using namespaces and seccomp
- **Docker/Podman** — Container-based isolation

The BlastShield *concept* (deny-by-default profiles, credential path blocking) could be adapted to bubblewrap or Firejail, but this is not currently implemented.

## Network Access

### Can BlastShield block network access?

Not by default. The sandbox profiles focus on file and process restrictions. Network access is allowed because:

1. AI agents need network access to function (API calls, package downloads, git operations)
2. `sandbox-exec` can technically restrict network, but doing so breaks most agent workflows

### Can secrets be exfiltrated over the network?

Yes, in certain scenarios. The sandbox operates at **file paths, not content**:

- If a secret is in an **environment variable** and you don't use `-c` (clean env), the agent can read it and send it over the network
- If a secret is fetched via a **credential helper** (e.g., `aws sts get-session-token`), the result enters the process and could be exfiltrated
- If a secret is in a **file protected by the sandbox**, it cannot be read at all

**Mitigation:** Use `-c` / `--clean-env` to strip API keys and secrets from environment variables:

```bash
blastshield -c claude --dangerously-skip-permissions
```

### Why is Keychain access allowed?

Keychain access is allowed so credential helpers work. Many cloud CLIs use the Keychain as their credential store. Blocking Keychain access would break authentication for legitimate operations (e.g., `git push`, `aws s3 ls`).

The trade-off: an agent can perform authenticated actions via credential helpers, but **cannot read raw tokens from files**. The guard layer provides additional protection by intercepting destructive subcommands.

## Guard

### Can an agent bypass blastshield-guard?

Yes, if it knows to use full paths. Running `/usr/local/bin/terraform destroy` bypasses the PATH wrapper. This is why:

1. **Layer 1 (sandbox) is the hard boundary** — Even with the guard bypassed, the agent cannot read credentials
2. **The guard is a speed bump** — It catches accidental and casual misuse, and makes deliberate misuse require more effort
3. **Use both layers** — Together they provide defense in depth

### Does BlastShield block package manager install commands?

Yes. The install profile and guard protect against 10 package managers: npm, yarn, pnpm, pip, brew, gem, cargo, hermit, apt, and dnf. Install/add subcommands are classified as mutating and require authentication. Read-only operations (`npm list`, `pip show`, `brew info`, `cargo search`, etc.) pass through immediately.

The sandbox profile also blocks writes to global package directories and project lockfiles at the kernel level, so even bypassing the PATH wrapper won't allow global installs.

**Note:** Project-local installs (e.g., `pip install` into a venv under the project directory) are only caught by the guard, since the base profile allows project writes. Use both layers for full protection.

### Can I add custom destructive patterns?

Not currently through a configuration file. The destructive command definitions are in the `blastshield-guard` script in the `DESTRUCTIVE_COMMANDS` associative array. You can modify them directly, or create custom wrappers in your guard directory.

## Limitations

### What are BlastShield's known limitations?

1. **macOS only** — `sandbox-exec` is Apple-specific
2. **sandbox-exec is deprecated** — Still works, but no guarantee for future macOS versions
3. **Network is open by default** — Secrets in env vars can be exfiltrated (use `-c`)
4. **Guard is bypassable** — Full paths bypass PATH wrappers
5. **No nested sandboxes** — Cannot use sandbox-exec inside another sandbox-exec
6. **Keychain is allowed** — Credential helpers can authenticate on the agent's behalf
7. **Content-level filtering is impossible** — sandbox-exec operates on paths, not file contents

When Conductor is launched through BlastShield, agents inside that Conductor session already inherit the sandbox. Do not run `blastshield` again from inside those agents; macOS may reject nested `sandbox-exec` launches.

### Can I use BlastShield inside a Docker container?

Not for its primary purpose. Docker on macOS runs inside a Linux VM, so `sandbox-exec` is not available. However, you can use BlastShield on the macOS host to sandbox a Docker CLI:

```bash
blastshield -p kubectl docker run ...
```

This would protect the Docker socket and kubeconfig files from being read by the agent.

## Troubleshooting

### `sandbox-exec not found`

BlastShield requires macOS. If you're on macOS and see this error, your system may have a non-standard configuration.

### Sandbox violations in logs

Check violations with:

```bash
blastshield --violations
```

This requires Full Disk Access for the terminal app. Grant it in **System Settings → Privacy & Security → Full Disk Access**.

### Agent can't access files it needs

The sandbox may be too restrictive. Options:

1. **Disable auto-detection** and specify only the profiles you need: `blastshield --no-detect -p terraform claude` (or `codex`, `opencode`)
2. **Create a custom profile** with additional allow rules: `~/.config/blastshield/profiles/custom.sb`
3. **Check violations** to understand what's being blocked: `blastshield --violations`
