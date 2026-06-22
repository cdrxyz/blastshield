---
title: Changelog
description: Recent BlastShield releases and the fixes included in each version.
---

## Unreleased

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
