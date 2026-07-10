---
title: Changelog
description: Recent BlastShield releases and the fixes included in each version.
---

## v0.1.19 — 2026-07-10

- Adds first-class Grok Build support in the base profile: allow runtime state writes under `~/.grok` (sessions, memory, logs, sockets, auto-update binaries).
- Protects Grok Build auth, configuration, policy, skills, plugins, hooks, and installed-plugin extension points from sandboxed writes.
- Documents `blastshield grok` / `blastshield grok --always-approve` in the README, getting started guide, FAQ, profiles reference, docs index, architecture, and whitepaper.
- Preserves Grok Build non-secret routing endpoints under `--clean-env` (`GROK_MODELS_BASE_URL`, `GROK_MODELS_LIST_URL`, `GROK_CLI_CHAT_PROXY_BASE_URL`).
- Adds integration tests covering allowed Grok runtime state and denied Grok auth/config/extension-point writes.

## v0.1.18 — 2026-06-22

- Adds `AGENTS.md` with repository instructions for future coding agents.
- Adds `CLAUDE.md` as a symlink to `AGENTS.md` so Claude uses the same instructions.
- Documents the requirement that every non-release commit updates the changelog with the next release number and includes relevant docs updates in the same commit.

## v0.1.17 — 2026-06-22

Release commit: `d4523c0`

- Allows Gradle builds to use `~/.gradle` cache, native, daemon, and wrapper state.
- Keeps Gradle user-level init/config files such as `~/.gradle/gradle.properties` and `~/.gradle/init.d` protected.
- Allows read-only GitHub CLI commands with IDs and JSON flags, including `gh pr view`, `gh pr checks`, and `gh run view/watch`.
- Allows read-only `gh api` GET/HEAD requests while continuing to block mutating API methods.
- Leaves Gradle commands unguarded by `blastshield-guard`.

## v0.1.16 — 2026-06-22

Release commit: `3a0a226`

- Allows sandboxed GUI apps to open external links and documents through Launch Services.
- Fixes clicking GitHub links and other external URLs from Conductor running under BlastShield.

## v0.1.15 — 2026-06-22

Release commit: `f89209d`

- Marks `conductor-app` as an intentional allow-only companion profile.
- Updates CI and local profile linting to accept explicitly marked allow-only profiles.

## v0.1.14 — 2026-06-22

Release commit: `48f2e4e`

- Allows Conductor workspace creation to materialize tracked project metadata such as `.idea`, `.vscode`, and `.mcp.json`.
- Removes Conductor-managed root denies that could break `git worktree` checkout.

## v0.1.13 — 2026-06-22

Release commit: `1fd49b4`

- Adds the Conductor documentation page.
- Documents the supported Conductor launch command and inherited sandbox behavior.
- Adds Conductor support to the docs index, sidebar, README, FAQ, getting started guide, profiles reference, architecture page, and whitepaper.

## v0.1.12 — 2026-06-22

Release commit: `3736add`

- Added the `conductor-app` profile.
- Auto-detects Conductor by bundle id `com.conductor.app`.
- Allows Conductor-launched agents to write under `~/conductor/workspaces`, `~/conductor/repos`, and `~/.conductor`.
- Keeps sensitive workspace persistence paths protected, including `.git/hooks`, `.git/config`, `.vscode`, `.idea`, and `.mcp.json`.

## v0.1.11 — 2026-06-22

Release commit: `2f61c6e`

- Keeps interactive terminals open for GUI app launches.
- Streams redirected GUI app logs in the terminal.
- Adds `--detach` for scripts or terminal profiles that should return immediately.
- Preserves the detached GUI process model so apps continue running after the log follow is stopped.

## v0.1.10 — 2026-06-15

Release commit: `4d2c6c4`

- Allows scoped Metal, CoreAnimation, IOAccelerator, IOSurface, and Apple Silicon GPU access for GUI apps.
- Fixes Metal-backed apps such as Zed failing with graphics-device enumeration errors.
- Allows GUI apps to write normal per-user logs under `~/Library/Logs`.
- Adds regression coverage for Metal device enumeration and user log writes.

## v0.1.9 — 2026-06-15

Release commit: `2484e47`

- Launches sandboxed GUI apps in a detached process instead of holding the app in the foreground.
- Redirects GUI app stdout and stderr to a temporary log file.
- Keeps temporary sandbox profile and guard directories alive until the GUI app exits.
- Adds regression coverage for detached `.app` launches and explicit GUI profile behavior.

## v0.1.8 — 2026-05-29

Release commit: `f6be224`

- Preserves BlastShield runtime guard path precedence across GUI app login-shell startup.
- Keeps guard wrappers ahead of user shell paths when GUI apps rebuild `PATH`.
- Improves `.app` launch compatibility for apps that inspect or modify shell environment.

## v0.1.7 — 2026-05-28

Release commit: `bceeb3f`

- Allows GUI apps to register for macOS power notifications.
- Fixes `IORegisterForSystemPower failed` errors seen during Conductor startup.
- Adds regression coverage for GUI power registration.

## v0.1.6 — 2026-05-20

Release commit: `20513ff`

- Allows WebKit sandbox extension issuance needed by embedded web views.
- Fixes `com.apple.webkit.mach-bootstrap` sandbox extension failures in GUI apps.
- Adds regression coverage for WebKit extension issuance.

## v0.1.5 — 2026-05-20

Release commit: `0a71c99`

- Skips project profile auto-detection for GUI app launches.
- Prevents project profiles such as `gh` from blocking normal GUI app startup checks.
- Lets users opt into specific GUI app restrictions with explicit `-p` profiles.
