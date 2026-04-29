---
title: Layering
description: How to compose BlastShield with sandvault, agent-safehouse, and agent-seatbelt for defense in depth.
---

## Why Layer?

No single sandbox tool covers every threat. Each tool has its own focus:

| Tool | Focus |
|------|-------|
| **BlastShield** | Cloud CLI destructive commands |
| **agent-safehouse** | Filesystem policy (dotfiles, project files) |
| **sandvault** | User isolation (separate macOS account) |
| **agent-seatbelt** | Minimal sandbox-exec wrapper |

BlastShield **composes** with all of them. Use them together for defense in depth.

## Composing with Other Tools

### With agent-safehouse

[agent-safehouse](https://github.com/eugene1g/agent-safehouse) provides composable filesystem profiles. Use it for file-level policy, and BlastShield for cloud CLI protection:

```bash
# blastshield (cloud CLI policy) → safehouse (file policy) → agent's sandbox
blastshield -p terraform -- safehouse claude --dangerously-skip-permissions
```

### With sandvault

[sandvault](https://github.com/webcoyote/sandvault) runs the agent in a separate macOS user account, providing user-level isolation. Layer BlastShield inside sandvault for cloud CLI protection within the isolated account:

```bash
# sandvault handles user isolation
# blastshield handles cloud CLI protection inside that account
sandvault -- blastshield -p aws -p terraform claude --dangerously-skip-permissions
```

### With agent-seatbelt

[agent-seatbelt](https://github.com/CJHwong/agent-seatbelt) is a minimal two-file sandbox-exec wrapper. Since both agent-seatbelt and BlastShield use `sandbox-exec`, they **cannot be nested** (macOS doesn't support recursive sandbox-exec). Choose one or the other for the sandbox-exec layer, and use BlastShield-guard for the additional command-level filtering.

```bash
# Option A: BlastShield for sandbox-exec + guard for command filtering
blastshield -p terraform claude --dangerously-skip-permissions

# Option B: Use seatbelt for sandbox-exec, add guard separately
# (if you prefer seatbelt's profiles for file policy)
agent-seatbelt claude --dangerously-skip-permissions
# Then separately:
export PATH="$HOME/.blastshield/guard:$PATH"
```

## The Full Stack

For maximum protection, layer all tools:

```
┌──────────────────────────────────────────┐
│  sandvault — separate macOS user account │
│  (user-level isolation)                  │
│  ┌────────────────────────────────────┐  │
│  │  blastshield — sandbox-exec        │  │
│  │  (kernel-level, cloud CLI policy)  │  │
│  │  ┌──────────────────────────────┐  │  │
│  │  │  blastshield-guard           │  │  │
│  │  │  (command-argument filter)   │  │  │
│  │  │  ┌────────────────────────┐  │  │  │
│  │  │  │  agent's built-in      │  │  │  │
│  │  │  │  sandbox               │  │  │  │
│  │  │  │  (tool-level gating)   │  │  │  │
│  │  │  │  ┌──────────────────┐  │  │  │  │
│  │  │  │  │  AI Agent        │  │  │  │  │
│  │  │  │  └──────────────────┘  │  │  │  │
│  │  │  └────────────────────────┘  │  │  │
│  │  └──────────────────────────────┘  │  │
│  └────────────────────────────────────┘  │
└──────────────────────────────────────────┘
```

## Practical Combinations

### Minimum Viable Protection

```bash
# Just BlastShield — covers cloud CLIs at kernel level
blastshield claude --dangerously-skip-permissions
```

### Recommended

```bash
# BlastShield + guard — kernel + command-level filtering
blastshield claude --dangerously-skip-permissions
blastshield-guard install
export PATH="$HOME/.blastshield/guard:$PATH"
```

### Maximum Protection

```bash
# Full stack: user isolation + cloud CLI sandbox + command guard + clean env
sandvault -- blastshield -c -p terraform -p aws claude --dangerously-skip-permissions
# Plus guard in PATH
export PATH="$HOME/.blastshield/guard:$PATH"
```

## Important: No Nested Sandboxes

macOS does **not** support recursive `sandbox-exec`. If an application already runs in a sandbox (e.g., a sandboxed app, or an outer sandbox-exec call), you cannot start another sandbox-exec inside it.

If you're already running inside a sandbox:
- Use `blastshield-guard` alone (it doesn't use sandbox-exec)
- Or restructure your setup so there's a single sandbox-exec layer

## Comparison Table

| Project | Approach | Cloud CLI Protection? | File/Secrets Protection? | User Isolation? |
|---------|----------|:---:|:---:|:---:|
| [sandvault](https://github.com/webcoyote/sandvault) | Separate macOS user + sandbox-exec | ❌ | ✅ | ✅ |
| [agent-safehouse](https://github.com/eugene1g/agent-safehouse) | Composable profiles | ❌ | ✅ | ❌ |
| [agent-seatbelt](https://github.com/CJHwong/agent-seatbelt) | Two-file minimal wrapper | ❌ | ✅ | ❌ |
| **BlastShield** | **sandbox-exec + command guard** | **✅** | **✅** | ❌ |
