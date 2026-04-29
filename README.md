# CloudSeal 🔒

**Sandbox AI coding agents with kernel-level protection against destructive cloud CLI commands.**

Uses macOS `sandbox-exec` (Apple Seatbelt) to enforce filesystem restrictions that prevent AI agents from executing destructive operations — `terraform destroy`, `gcloud compute instances delete`, `aws s3 rb`, `az group delete`, `kubectl delete namespace` — even when running with `--dangerously-skip-permissions` or equivalent unrestricted modes.

## Why This Exists

Existing macOS sandbox tools for AI agents ([sandvault](https://github.com/webcoyote/sandvault), [agent-safehouse](https://github.com/eugene1g/agent-safehouse), [agent-seatbelt](https://github.com/CJHwong/agent-seatbelt)) focus on protecting secrets and dotfiles. **None of them address cloud CLI destructive commands.** An agent with access to your cloud credentials can delete your infrastructure in seconds. CloudSeal fills that gap.

Built-in agent sandboxes (Claude's `/sandbox`, Codex's approval policies) only gate their own tools. An agent that shells out via Bash or Python bypasses all of it. OS-level enforcement can't be bypassed — the kernel doesn't care what the agent thinks it's allowed to do.

## Two Layers of Defense

### Layer 1: `cloudseal` — Filesystem/Process Sandbox (sandbox-exec)

Kernel-level. Blocks access to credential files, state files, and protected paths. The agent process physically cannot read or write the files it would need to authenticate destructive operations.

```bash
# Run Claude Code with all auto-detected cloud protections
cloudseal claude --dangerously-skip-permissions

# Run Codex with explicit profiles
cloudseal -p terraform -p aws codex

# Run any command
cloudseal -p kubectl bash
```

### Layer 2: `cloudseal-guard` — Command-Argument Filter (sudo/Touch ID)

`sandbox-exec` operates at file/process level and cannot filter by command arguments. CloudSeal Guard wraps cloud CLIs and requires biometric/password authentication before allowing destructive subcommands.

```bash
# Install guard wrappers
cloudseal-guard install

# Add to PATH (before real CLIs)
export PATH="$HOME/.cloudseal/guard:$PATH"
```

Now `terraform destroy` prompts for Touch ID. `terraform plan` passes through immediately.

## Quick Start

```bash
# Clone
git clone https://github.com/cdrxyz/cloudseal.git
cd cloudseal

# Add to PATH
export PATH="$PWD:$PATH"

# Run Claude Code sandboxed
cloudseal claude --dangerously-skip-permissions

# Install command-level guards
cloudseal-guard install ~/.cloudseal/guard
export PATH="$HOME/.cloudseal/guard:$PATH"

# Check status
cloudseal --status
```

## Usage

### Basic

```bash
# Auto-detect cloud profiles from project directory
cloudseal claude --dangerously-skip-permissions

# Explicit profiles
cloudseal -p terraform codex
cloudseal -p gcloud -p aws opencode

# Clean environment (strip API keys from env vars)
cloudseal -c claude --dangerously-skip-permissions

# Disable auto-detection
cloudseal --no-detect claude
```

### With Other Sandbox Tools

CloudSeal composes with existing tools — layer them for defense in depth:

```bash
# cloudseal (cloud CLI policy) → safehouse (file policy) → agent's sandbox
cloudseal -p terraform -- safehouse claude --dangerously-skip-permissions
```

### Guard Installation

```bash
# Install to default location
cloudseal-guard install

# Install to custom location
cloudseal-guard install ~/bin/guard

# List guarded CLIs
cloudseal-guard list

# Check if a command would be blocked
cloudseal-guard check terraform destroy    # exit 1 = blocked
cloudseal-guard check terraform plan       # exit 0 = allowed

# Uninstall
cloudseal-guard uninstall
```

### Diagnostics

```bash
# Show detected CLIs and auto-detected profiles
cloudseal --status

# Show recent sandbox violations from system log
cloudseal --violations
```

## Protected Commands

### Terraform Profile

| Blocked | Allowed |
|---------|---------|
| `terraform destroy` | `terraform plan` |
| `terraform apply -destroy` | `terraform apply` (create/update) |
| State file writes | `terraform init, fmt, validate` |
| Backend config writes | `terraform show, output, state list` |
| Provider replacement | `terraform import, taint` |

### gcloud Profile

| Blocked | Allowed |
|---------|---------|
| Credential reads | `gcloud * list/describe` |
| Service account key reads | `gcloud * create/deploy` |
| Application default credentials | `gcloud * get-credentials` |
| ADC writes | `gcloud auth status` |

### AWS Profile

| Blocked | Allowed |
|---------|---------|
| `~/.aws/credentials` reads | `~/.aws/config` reads |
| SSO token cache reads | `aws * describe/list/get` |
| State file writes | `aws * create/run/start` |
| CDK/SAM state writes | `aws sts get-caller-identity` |

### Azure Profile

| Blocked | Allowed |
|---------|---------|
| `~/.azure` reads | `az * list/show` |
| SP credential reads | `az * create/deploy` |
| ARM template writes | `az * get-credentials` |
| MSAL token cache | `az account show` |

### kubectl Profile

| Blocked | Allowed |
|---------|---------|
| Kubeconfig writes | Kubeconfig reads |
| Service account tokens | `kubectl get/describe/logs` |
| Helm chart lock writes | `kubectl apply/exec/port-forward` |
| Namespace manifest writes | `kubectl config use-context` |

### gh (GitHub CLI) Profile

| Blocked | Allowed |
|---------|---------|
| `hosts.yml` reads | `gh repo list/view/clone` |
| Workflow file writes | `gh pr/issue create` |
| CODEOWNERS writes | `gh release create` |
| Dependabot config writes | `gh auth status` |

## Architecture

```
┌─────────────────────────────────────────────────┐
│                  AI Agent                        │
│  (Claude Code, Codex, Cursor, Gemini, etc.)     │
└──────────────────┬──────────────────────────────┘
                   │
    ┌──────────────┼──────────────────┐
    │              ▼                   │
    │  Layer 2: cloudseal-guard        │
    │  (command-argument filter)       │
    │  • Intercepts destructive        │
    │    subcommands via PATH wrappers │
    │  • Requires Touch ID / password  │
    │  • Passes safe commands through  │
    └──────────────┬──────────────────┘
                   │
    ┌──────────────┼──────────────────┐
    │              ▼                   │
    │  Layer 1: cloudseal             │
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

### Custom Profiles

Create profiles in `~/.config/cloudseal/profiles/`:

```scheme
;; ~/.config/cloudseal/profiles/custom.sb
;; Deny access to internal API keys directory
(deny file-read* (subpath "/Users/you/secrets"))
(deny file-write* (subpath "/Users/you/secrets"))
```

Load with `-p`:

```bash
cloudseal -p custom claude
```

### Auto-Detection

CloudSeal scans your project directory for indicator files:

| Profile | Triggers |
|---------|----------|
| `terraform` | `*.tf` files |
| `gcloud` | `.gcloudignore`, `cloudbuild.yaml`, `app.yaml` |
| `aws` | `serverless.yml`, `template.yaml`, `cdk.json`, `samconfig.toml` |
| `azure` | `azure-pipelines.yml`, `local.settings.json` |
| `kubectl` | `kustomization.yaml`, `Chart.yaml`, `skaffold.yaml` |
| `gh` | `.github/` directory |

## Caveats

- **macOS only.** `sandbox-exec` is Apple-specific. For Linux, use [bubblewrap](https://github.com/containers/bubblewrap).
- **sandbox-exec is deprecated** by Apple (since 10.15). Still works on Sequoia. No replacement exists for ad-hoc CLI sandboxing.
- **Network is open by default.** If a secret enters the process (env var without `-c`, or fetched via credential helper), it can be exfiltrated. The sandbox operates at file paths, not content.
- **Keychain access is allowed** so credential helpers work. An agent can perform authenticated actions (e.g., `git push`) but cannot read raw tokens from files.
- **Layer 2 (guard) is a speed bump**, not a hard boundary. A determined agent that specifies full paths to CLIs bypasses PATH wrappers. Layer 1 (sandbox) is the hard boundary.
- **No nested sandboxes.** macOS doesn't support recursive `sandbox-exec`. If an app already runs in a sandbox, use `--no-sandbox` equivalent.

## Related Projects

| Project | Approach | Cloud CLI Protection? |
|---------|----------|----------------------|
| [sandvault](https://github.com/webcoyote/sandvault) | Separate macOS user account + sandbox-exec | ❌ File/secrets only |
| [agent-safehouse](https://github.com/eugene1g/agent-safehouse) | Composable profiles, Homebrew, website | ❌ File/secrets only |
| [agent-seatbelt](https://github.com/CJHwong/agent-seatbelt) | Two-file minimal wrapper | ❌ File/secrets only |
| **CloudSeal** | **sandbox-exec + command-argument guard** | **✅ Cloud CLI focus** |

CloudSeal composes with all of the above. Use sandvault for user isolation, safehouse for file policy, and CloudSeal for cloud CLI protection.

## License

MIT
