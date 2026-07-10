---
title: Getting Started
description: Installation, first run, and configuration guide for BlastShield.
---

> [!WARNING]
> BlastShield is still in beta and may contain bugs. Validate it in a non-production environment before depending on it for safety-critical workflows.

**Sandbox AI coding agents with kernel-level protection against destructive cloud CLI commands.**

Uses macOS `sandbox-exec` (Apple Seatbelt) to enforce filesystem restrictions that prevent AI agents from executing destructive operations — `terraform destroy`, `gcloud compute instances delete`, `aws s3 rb`, `az group delete`, `kubectl delete namespace` — even when running with `--dangerously-skip-permissions` or equivalent unrestricted modes.

## Why This Exists

Existing macOS sandbox tools for AI agents ([sandvault](https://github.com/webcoyote/sandvault), [agent-safehouse](https://github.com/eugene1g/agent-safehouse), [agent-seatbelt](https://github.com/CJHwong/agent-seatbelt)) focus on protecting secrets and dotfiles. **None of them address cloud CLI destructive commands.** An agent with access to your cloud credentials can delete your infrastructure in seconds. BlastShield fills that gap.

Built-in agent sandboxes (Claude's `/sandbox`, Codex's approval policies) only gate their own tools. An agent that shells out via Bash or Python bypasses all of it. OS-level enforcement can't be bypassed — the kernel doesn't care what the agent thinks it's allowed to do.

## Two Layers of Defense

### Layer 1: `blastshield` — Filesystem/Process Sandbox (sandbox-exec)

Kernel-level. Blocks access to credential files, state files, and protected paths. The agent process physically cannot read or write the files it would need to authenticate destructive operations.

```bash
# Run Claude Code with all auto-detected cloud protections
blastshield claude --dangerously-skip-permissions

# Run Codex with full auto-approve
blastshield codex --full-auto

# Run Grok Build with always-approve (Grok's unrestricted tool mode)
blastshield grok --always-approve

# Run OpenCode with explicit profiles
blastshield -p terraform -p aws opencode

# Run any command
blastshield -p kubectl bash
```

### Layer 2: `blastshield-guard` — Command-Argument Filter

`sandbox-exec` operates at file/process level and cannot filter by command arguments. BlastShield Guard wraps cloud CLIs and blocks destructive subcommands. When launched through `blastshield`, temporary runtime wrappers are injected automatically ahead of your current `PATH`, including repo-local and Hermit shims invoked by command name.

Persistent wrappers are also available for regular shell use outside BlastShield:

```bash
# Install guard wrappers
blastshield-guard install

# Add to PATH (before real CLIs)
export PATH="$HOME/.blastshield/guard:$PATH"
```

Persistent wrappers prompt for Touch ID. Runtime wrappers hard-block mutating commands inside the agent sandbox. `terraform plan` passes through immediately.

## Installation

### Homebrew (recommended)

```bash
brew install cdrxyz/tap/blastshield
```

### Advanced: Manual Installation

```bash
# Clone
git clone https://github.com/cdrxyz/blastshield.git
cd blastshield

# Add to PATH
export PATH="$PWD:$PATH"
```

## Usage

### Basic

```bash
# Auto-detect cloud profiles from project directory
blastshield claude --dangerously-skip-permissions

# Or with Codex
blastshield codex --full-auto

# Or with Grok Build
blastshield grok --always-approve

# Or with OpenCode
blastshield opencode

# Explicit profiles
blastshield -p terraform codex
blastshield -p gcloud -p aws opencode
blastshield -p terraform grok --always-approve

# Clean environment (strip API keys from env vars)
blastshield -c claude --dangerously-skip-permissions
blastshield -c codex --full-auto
blastshield -c grok --always-approve
blastshield -c opencode

# Disable auto-detection
blastshield --no-detect claude
blastshield --no-detect codex
blastshield --no-detect grok
blastshield --no-detect opencode
```

### With Other Sandbox Tools

BlastShield composes with existing tools — layer them for defense in depth:

```bash
# blastshield (cloud CLI policy) → safehouse (file policy) → agent's sandbox
blastshield -p terraform -- safehouse claude --dangerously-skip-permissions
blastshield -p aws -- safehouse codex --full-auto
blastshield -p kubectl -- safehouse opencode
```

### With GUI Agent Apps (Conductor, Zed, Cursor, IntelliJ, VSCode)

Many AI agent IDEs and launcher apps run as GUI applications but still spawn agent CLIs as child processes. BlastShield can protect those sessions by wrapping the app's process using the macOS `open` command.

**General pattern for any GUI app:**

```bash
blastshield open /Applications/AppName.app
```

When BlastShield detects a `.app` launch, it automatically adds the `gui-app` profile, resolves the real bundle executable, and runs it under the sandbox. Passing `-p gui-app` explicitly is still fine and makes the intent clear:

```bash
blastshield -p gui-app open /Applications/Conductor.app
```

For interactive terminals, BlastShield streams the GUI app log and keeps the terminal open. Press `Ctrl-C` to stop following logs; the app keeps running. Use `--detach` for scripts or terminal profiles that should return immediately:

```bash
blastshield --detach -p gui-app open /Applications/Conductor.app
```

When BlastShield detects a `.app` launch, it skips project profile auto-detection so app startup checks can use normal CLI auth configuration such as GitHub CLI's `hosts.yml`. Runtime guards still stay on the app's `PATH`, and GUI apps can open normal external links through Launch Services. Add explicit profiles with `-p terraform`, `-p gh`, or similar if you want those profile-level credential restrictions for a GUI app.

This works for:
- Conductor (`/Applications/Conductor.app`)
- Zed (`/Applications/Zed.app`)
- Cursor (`/Applications/Cursor.app`)
- IntelliJ IDEA (`/Applications/IntelliJ\ IDEA.app`)
- VSCode (`/Applications/Visual\ Studio\ Code.app`)

**Why this works:** `open` launches the app, and BlastShield's sandbox applies to the app process and all its children. When the app spawns `codex`, `claude`, or other agent CLIs, those child processes inherit the sandbox restrictions and runtime guards.

**Alternate pattern (if the app supports custom agent commands):**

Configure the app to run the BlastShield-wrapped CLI directly:

```bash
blastshield codex --full-auto
blastshield claude --dangerously-skip-permissions
blastshield opencode
```

**What matters is the process tree:** The sandbox applies to the process and child processes started inside BlastShield. If the app launches agent processes inside that tree, both the filesystem sandbox and command-argument guards protect the session. If the app hands work off to an already-running service outside that process tree, BlastShield cannot protect it.

**Conductor-specific example:**

```bash
# Wrap Conductor itself. BlastShield also auto-adds the conductor-app profile.
blastshield -p gui-app open /Applications/Conductor.app
```

Conductor is first-class supported. The `conductor-app` profile allows Conductor-launched agents to write under `~/conductor/workspaces`, `~/conductor/repos`, and `~/.conductor`, including tracked project metadata needed during `git worktree` checkout. See the [Conductor guide](../conductor/) for details.

### Guard Installation

Runtime guards are enabled automatically by `blastshield`. Use `--no-guard` to disable them for a launch.

```bash
# Install to default location
blastshield-guard install

# Install to custom location
blastshield-guard install ~/bin/guard

# List guarded CLIs
blastshield-guard list

# Check if a command would be blocked
blastshield-guard check terraform destroy    # exit 1 = blocked
blastshield-guard check terraform plan       # exit 0 = allowed

# Uninstall
blastshield-guard uninstall
```

### Diagnostics

```bash
# Show detected CLIs and auto-detected profiles
blastshield --status

# Show recent sandbox violations from system log
blastshield --violations
```

## Protected Commands

### Terraform Profile

| Blocked | Allowed |
|---------|---------|
| `terraform apply` | `terraform plan` |
| `terraform destroy` | `terraform init, fmt, validate` |
| `terraform import, taint, untaint` | `terraform show, output, console` |
| `terraform refresh` | `state list, state show` |
| `terraform state rm/mv` | `workspace list, workspace select` |
| ALL tfstate writes | `terraform providers, version, graph` |

### gcloud Profile

| Blocked | Allowed |
|---------|---------|
| `gcloud * delete/create/deploy/update` | `gcloud * list/describe/get` |
| `gcloud * add/remove/patch/set` | `gcloud auth status` |
| `gcloud * enable/disable/submit` | `gcloud config list/get` |
| `gcloud builds submit` | `gcloud version, help` |
| `gcloud app deploy` | |
| Service account key reads | |

### AWS Profile

| Blocked | Allowed |
|---------|---------|
| `aws * delete/create/put/update` | `aws * describe-/list-/get-` |
| `aws * deploy/terminate/run-` | `aws s3 ls, cp (download), presign` |
| `aws * start-/stop-/reboot` | `aws sts get-caller-identity` |
| `aws * authorize/revoke/send` | `aws logs describe-/get-/filter-` |
| Credential reads | `aws dynamodb scan/query/get-item` |
| SSO token cache reads | `aws iam list-/get-` |
| CDK/SAM state writes | `aws lambda list-, invoke` |

### Azure Profile

| Blocked | Allowed |
|---------|---------|
| `az * delete/create/update/deploy` | `az * list/show` |
| `az * set/remove/add/lock/unlock` | `az account show/list` |
| `az * scale/restart` | `az version, help` |
| ALL `~/.azure` access | |

### kubectl Profile

| Blocked | Allowed |
|---------|---------|
| `kubectl apply/create/delete` | `kubectl get/describe/logs` |
| `kubectl patch/scale/exec` | `kubectl top, events` |
| `kubectl taint/cordon/uncordon/drain` | `kubectl api-resources/versions/explain` |
| `kubectl rollout restart/undo` | `kubectl auth can-i` |
| `kubectl label/annotate/set` | `kubectl config view/get-contexts` |
| `kubectl expose/run/cp/debug` | `kubectl rollout status/history` |
| Kubeconfig writes | `kubectl version` |
| Helm install/upgrade/delete | Helm list/status/show/search |

### gh (GitHub CLI) Profile

| Blocked | Allowed |
|---------|---------|
| `gh repo delete/edit/rename` | `gh repo list/view/clone/fork` |
| `gh pr create/merge/close/edit` | `gh pr list/view/diff/checks/status/checkout` |
| `gh release delete` | `gh release create/list/view/download` |
| `gh workflow disable/enable` | `gh workflow list/view` |
| `gh run cancel` | `gh run list/view/watch` |
| `gh issue create/close/comment` | `gh issue list/view` |
| `gh api -X DELETE/PUT/PATCH/POST` | `gh api` with GET/HEAD |
| Workflow file writes | `gh auth status` |
| CODEOWNERS writes, `gh secret set` | |

### Install (Package Manager) Profile

Blocks AI agents from installing new dependencies without human review. Protects both the command-argument level (via guard) and the filesystem level (via sandbox profile).

| Blocked | Allowed |
|---------|---------|
| `npm install / ci / add` | `npm list / ls / view / info / outdated` |
| `yarn add / install / remove` | `yarn list / info / why / outdated` |
| `pnpm add / install / remove` | `pnpm list / info / why / outdated` |
| `pip install / uninstall / build` | `pip list / show / freeze / check` |
| `brew install / reinstall / uninstall` | `brew list / info / search / outdated` |
| `gem install / uninstall / build` | `gem list / search / spec / query` |
| `cargo install / add / rm` | `cargo search / tree / list / metadata` |
| `hermit install / uninstall / upgrade` | `hermit list / search / help / info` |
| `apt install / remove / purge` | `apt list / search / show / cache` |
| `dnf install / remove / upgrade` | `dnf list / search / info / check` |
| Global package directories (writes) | Global package directories (reads) |
| Lockfile writes | Lockfile reads |

## Architecture

```
┌─────────────────────────────────────────────────┐
│                  AI Agent                        │
│  (Claude Code, Codex, Grok Build, Conductor, Cursor, Gemini, etc.)   │
└──────────────────┬──────────────────────────────┘
                   │
    ┌──────────────┼──────────────────┐
    │              ▼                   │
    │  Layer 2: blastshield-guard        │
    │  (command-argument filter)       │
    │  • Intercepts destructive        │
    │    subcommands via PATH wrappers │
    │  • Requires Touch ID / password  │
    │  • Passes safe commands through  │
    └──────────────┬──────────────────┘
                   │
    ┌──────────────┼──────────────────┐
    │              ▼                   │
    │  Layer 1: blastshield             │
    │  (sandbox-exec profiles)        │
    │  • Kernel-enforced file policy   │
    │  • Blocks credential reads       │
    │  • Blocks state file writes      │
    │  • Protects backend configs      │
    └──────────────┬──────────────────┘
                   │
    ┌──────────────┼──────────────────┐
    │              ▼                   │
    │  Layer 0: agent's built-in       │
    │  sandbox (Claude /sandbox,       │
    │  Codex approval policies)        │
    │  • Tool-level gating            │
    │  • Network filtering            │
    └──────────────┬──────────────────┘
                   │
                   ▼
              macOS Kernel
```

Each layer handles what the layer above cannot:
- **Layer 0** handles tool-level permissions (agent's own sandbox)
- **Layer 1** handles filesystem/process-level restrictions (kernel-enforced, cannot be bypassed)
- **Layer 2** handles command-argument filtering (what sandbox-exec cannot see)

## Profile System

Profiles are [SBPL](https://reverse.put.as/wp-content/uploads/2011/09/Apple-Sandbox-Guide-v1.0.pdf) (Seatbelt Profile Language) files in `profiles/`. They compose by intersection — every deny rule from every profile is enforced.

### Built-in Profiles

| Profile | Always Loaded | Purpose |
|---------|--------------|---------|
| `base` | ✅ | Minimum viable sandbox: deny-all default, project writes, system reads |
| `secrets` | ✅ | Protect SSH keys, cloud creds, browser data, shell init files |
| `terraform` | Auto | State file protection, backend config locks, credential denial |
| `gcloud` | Auto | GCP credential protection, SA key denial, ADC protection |
| `aws` | Auto | AWS credential protection, SSO cache denial, state locks |
| `azure` | Auto | Azure credential protection, MSAL cache denial, ARM protection |
| `kubectl` | Auto | Kubeconfig write protection, SA token denial, Helm lock protection |
| `gh` | Auto | GitHub auth protection, workflow file protection, CODEOWNERS locks |
| `install` | Auto | Package manager install blocking, lockfile protection, global dir protection |

### Custom Profiles

Create profiles in `~/.config/blastshield/profiles/`:

```scheme
;; ~/.config/blastshield/profiles/custom.sb
;; Deny access to internal API keys directory
(deny file-read* (subpath "/Users/you/secrets"))
(deny file-write* (subpath "/Users/you/secrets"))
```

Load with `-p`:

```bash
blastshield -p custom claude
```

### Auto-Detection

BlastShield scans your project directory for indicator files:

| Profile | Triggers |
|---------|----------|
| `terraform` | `*.tf` files |
| `gcloud` | `.gcloudignore`, `cloudbuild.yaml`, `app.yaml` |
| `aws` | `serverless.yml`, `template.yaml`, `cdk.json`, `samconfig.toml` |
| `azure` | `azure-pipelines.yml`, `local.settings.json` |
| `kubectl` | `kustomization.yaml`, `Chart.yaml`, `skaffold.yaml` |
| `gh` | `.github/` directory |
| `install` | `package.json`, `requirements.txt`, `Pipfile`, `pyproject.toml`, `Gemfile`, `Cargo.toml`, `go.mod`, `.hermit` |

## Caveats

- **macOS only.** `sandbox-exec` is Apple-specific. For Linux, use [bubblewrap](https://github.com/containers/bubblewrap).
- **sandbox-exec is deprecated** by Apple (since 10.15). Still works on Sequoia. No replacement exists for ad-hoc CLI sandboxing.
- **Network is open by default.** If a secret enters the process (env var without `-c`, or fetched via credential helper), it can be exfiltrated. The sandbox operates at file paths, not content.
- **Keychain access is allowed** so credential helpers work. An agent can perform authenticated actions (e.g., `git push`) but cannot read raw tokens from files.
- **Layer 2 (guard) is a speed bump**, not a hard boundary. A determined agent that specifies full paths to CLIs bypasses PATH wrappers. Runtime guards cover Hermit and repo-local shims when invoked by command name. Layer 1 (sandbox) is the hard boundary.
- **No nested sandboxes.** macOS doesn't support recursive `sandbox-exec`. If an app already runs in a sandbox, use `--no-sandbox` equivalent.

## Related Projects

| Project | Approach | Cloud CLI Protection? |
|---------|----------|----------------------|
| [sandvault](https://github.com/webcoyote/sandvault) | Separate macOS user account + sandbox-exec | ❌ File/secrets only |
| [agent-safehouse](https://github.com/eugene1g/agent-safehouse) | Composable profiles, Homebrew, website | ❌ File/secrets only |
| [agent-seatbelt](https://github.com/CJHwong/agent-seatbelt) | Two-file minimal wrapper | ❌ File/secrets only |
| **BlastShield** | **sandbox-exec + command-argument guard** | **✅ Cloud CLI focus** |

BlastShield composes with all of the above. Use sandvault for user isolation, safehouse for file policy, and BlastShield for cloud CLI protection.

## License

Apache License 2.0
