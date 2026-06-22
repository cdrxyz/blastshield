---
title: Conductor
description: How to run Conductor under BlastShield so Claude Code and Codex agents inherit sandbox and guard protections.
---

BlastShield supports running [Conductor](https://conductor.build/) as a sandboxed macOS GUI app. This lets Conductor-launched Claude Code and Codex agents inherit BlastShield's kernel sandbox and runtime command guards.

## Launch Command

```bash
blastshield -p gui-app open /Applications/Conductor.app
```

BlastShield detects the `.app` bundle, resolves the real bundle executable, and launches it directly under `sandbox-exec`. For Conductor specifically, BlastShield also detects `CFBundleIdentifier = com.conductor.app` and automatically adds the `conductor-app` profile.

Expected output includes:

```text
[blastshield] Detected .app bundle — auto-adding 'gui-app' profile and bypassing 'open'
[blastshield] Detected Conductor app — auto-adding 'conductor-app' profile
[blastshield] Launching GUI app in sandbox with profile: ...
[blastshield] GUI app launched in sandbox as PID ...
[blastshield] GUI app logs: ...
```

In an interactive terminal, BlastShield keeps the terminal open and streams the app log. Press `Ctrl-C` to stop following logs; the Conductor app keeps running. Use `--detach` when you want the command to return immediately:

```bash
blastshield --detach -p gui-app open /Applications/Conductor.app
```

## What Is Protected

Conductor starts agents as child processes. When Conductor is launched through BlastShield, those agents inherit:

- The assembled Seatbelt sandbox profile.
- Runtime `blastshield-guard` wrappers at the front of `PATH`.
- GUI compatibility allowances needed for WebKit, power registration, Metal-backed rendering, app logs, and normal app state.
- The Conductor-specific workspace allowances described below.

Mutating cloud and package-manager commands are still blocked by the guard layer. Add explicit profiles when you want profile-level credential restrictions for a GUI session:

```bash
blastshield -p gui-app -p terraform -p aws open /Applications/Conductor.app
```

## Conductor Workspace Writes

Conductor creates and manages workspaces outside the directory where you launch the app. The `conductor-app` profile allows writes to:

- `~/conductor/workspaces`
- `~/conductor/repos`
- `~/.conductor`

Those writes are needed for agents to edit files in Conductor workspaces. The profile still blocks persistence-sensitive writes under Conductor-managed roots:

- `.git/hooks`
- `.git/config`
- `.vscode`
- `.idea`
- `.mcp.json`

## GUI App Behavior

For `.app` launches, BlastShield skips project profile auto-detection by default. GUI apps run startup checks that often need normal CLI auth files, such as GitHub CLI config. Runtime guards still stay on `PATH`.

If you want additional restrictions for the GUI app and all child agents, opt in with explicit profiles:

```bash
blastshield -p gui-app -p gh open /Applications/Conductor.app
```

## After Updating BlastShield

Sandbox permissions are fixed when the process starts. If you update BlastShield, fully quit and relaunch Conductor through BlastShield before testing a new profile change:

```bash
blastshield --version
blastshield -p gui-app open /Applications/Conductor.app
```

## Limitations

BlastShield protects the process tree it starts. If Conductor hands work to an already-running process outside that tree, that process will not inherit BlastShield's sandbox.

macOS does not allow starting a new `sandbox-exec` sandbox from inside an existing one in some environments. In practice, do not run `blastshield` again from an agent that is already inside a BlastShield-launched Conductor session.
