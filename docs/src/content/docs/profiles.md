---
title: Profiles
description: All 11 BlastShield profiles — base, secrets, terraform, gcloud, aws, azure, kubectl, gh, install, gui-app, conductor-app — enforcing read-only cloud access, GUI compatibility, and Conductor workspace policy.
---

## Read-Only Philosophy

All cloud profiles enforce a **default-deny** posture for mutations. The AI agent can inspect resources (`list`, `describe`, `get`, `plan`) but cannot modify them. Any mutating operation — `apply`, `deploy`, `create`, `delete`, `update` — requires the user to run it manually.

This is by design: the agent plans, **you** execute.

## Profile System

Profiles are [SBPL](https://reverse.put.as/wp-content/uploads/2011/09/Apple-Sandbox-Guide-v1.0.pdf) (Seatbelt Profile Language) files in `profiles/`. They compose by **intersection** — every deny rule from every loaded profile is enforced.

For `.app` launches, BlastShield uses GUI compatibility mode: it skips the always-loaded `secrets` profile and skips project profile auto-detection, because long-lived GUI apps often run startup checks that need normal CLI auth files. BlastShield automatically adds `gui-app` for `.app` bundles and `conductor-app` for Conductor's `com.conductor.app` bundle id. Explicit `-p` profiles still apply.

### Built-in Profiles

| Profile | Always Loaded | Purpose |
|---------|:---:|---------|
| `base` | ✅ | Deny-all default, project writes, system reads |
| `secrets` | ✅ | Protect SSH keys, cloud creds, browser data |
| `terraform` | Auto | State file protection, deny all tfstate writes |
| `gcloud` | Auto | GCP credential protection, ADC denial |
| `aws` | Auto | AWS credential protection, SSO cache denial |
| `azure` | Auto | Azure credential protection, MSAL cache denial |
| `kubectl` | Auto | Kubeconfig write protection, SA token denial |
| `gh` | Auto | GitHub auth protection, workflow file locks |
| `install` | Auto | Package manager install blocking, lockfile protection, global dir protection |
| `gui-app` | `.app` | GUI app compatibility for Launch Services-style apps |
| `conductor-app` | Conductor `.app` | Conductor-managed workspace and repo writes |

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

---

## base (Always Loaded)

The foundation of every BlastShield session. Establishes a deny-by-default policy and opens only the minimal paths needed for an agent to function.

| Policy | Detail |
|--------|--------|
| Default | Deny all |
| Project writes | Allowed in current working directory |
| System reads | Allowed for standard system paths |
| Process execution | Allowed for standard binary paths |
| Network | Outbound allowed, inbound allowed |
| Codex runtime writes | Allowed under `~/.codex`, except auth/config/rules/skills/memories |
| Claude runtime writes | Allowed under `~/.claude`, except settings/plugins/native integration |
| Grok Build runtime writes | Allowed under `~/.grok` for sessions, memory, logs, sockets, and auto-update binaries; auth, config, policy, skills, plugins, and hooks stay protected |
| Gradle cache/state writes | Allowed under `~/.gradle`, except user-level init/config files |
| Mount/unmount | Denied |
| IOKit | Denied |

## secrets (Always Loaded)

Protects the most sensitive files on your system — the ones that, if read by an AI agent, would give it credentials to act on your behalf.

| Protected | Path |
|-----------|------|
| SSH keys | `~/.ssh/` |
| Cloud credentials | `~/.aws/`, `~/.azure/`, `~/.config/gcloud/` |
| Browser data | Safari, Chrome, Firefox profile data |
| Shell init files | `.bashrc`, `.zshrc`, `.profile` |
| Git credentials | `~/.gitconfig`, `~/.netrc` |

---

## terraform

Prevents ALL state mutations — not just `destroy`. The agent can `plan` but not `apply`. State files are read-only.

| Blocked | Allowed |
|---------|---------|
| `terraform apply` | `terraform plan` |
| `terraform destroy` | `terraform init, fmt, validate` |
| `terraform import, taint, untaint` | `terraform show, output, console` |
| `terraform refresh` | `state list, state show` |
| `terraform state rm/mv` | `workspace list, workspace select` |
| ALL tfstate writes | `terraform providers, version, graph` |
| Plan file writes (`.tfplan`) | |
| Provider/module downloads | |

**Auto-detection trigger:** `*.tf` files in project directory

## gcloud

Protects GCP credentials and blocks ALL mutating gcloud operations.

| Blocked | Allowed |
|---------|---------|
| `gcloud * delete/create/deploy/update` | `gcloud * list/describe/get` |
| `gcloud * add/remove/patch/set` | `gcloud auth status` |
| `gcloud * enable/disable/submit` | `gcloud config list/get` |
| `gcloud builds submit` | `gcloud version, help` |
| `gcloud app deploy` | |
| Service account key reads | |

**Auto-detection trigger:** `.gcloudignore`, `cloudbuild.yaml`, `app.yaml`

## aws

Protects AWS credentials and blocks ALL mutating AWS CLI operations.

| Blocked | Allowed |
|---------|---------|
| `aws * delete/create/put/update` | `aws * describe-/list-/get-` |
| `aws * deploy/terminate/run-` | `aws s3 ls, cp (download), presign` |
| `aws * start-/stop-/reboot` | `aws sts get-caller-identity` |
| `aws * authorize/revoke/send` | `aws logs describe-/get-/filter-` |
| Credential reads | `aws dynamodb scan/query/get-item` |
| SSO token cache reads | `aws iam list-/get-` |
| CDK/SAM state writes | `aws lambda list-, invoke` |

**Auto-detection trigger:** `serverless.yml`, `template.yaml`, `cdk.json`, `samconfig.toml`

## azure

Protects Azure credentials and blocks ALL mutating Azure CLI operations.

| Blocked | Allowed |
|---------|---------|
| `az * delete/create/update/deploy` | `az * list/show` |
| `az * set/remove/add/lock/unlock` | `az account show/list` |
| `az * scale/restart` | `az version, help` |
| ALL `~/.azure` access | |

**Auto-detection trigger:** `azure-pipelines.yml`, `local.settings.json`

## kubectl

Protects Kubernetes cluster access — read-only inspection only.

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

**Auto-detection trigger:** `kustomization.yaml`, `Chart.yaml`, `skaffold.yaml`

## gh (GitHub CLI)

Protects GitHub authentication — prevents destructive repo operations and CI manipulation.

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

**Auto-detection trigger:** `.github/` directory

## install (Package Managers)

Prevents AI agents from installing new dependencies without human review. Adding packages introduces supply chain risk, license obligations, and runtime bloat. Both the command-argument level (guard) and the filesystem level (sandbox profile) are protected.

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

**Auto-detection trigger:** `package.json`, `requirements.txt`, `Pipfile`, `pyproject.toml`, `Gemfile`, `Cargo.toml`, `go.mod`, `.hermit`

**Filesystem protections:**
- Denies writes to global npm/yarn/pnpm directories
- Denies writes to pip cache and user site-packages
- Denies writes to Homebrew Cellar, Caskroom, and Taps
- Denies writes to gem, cargo, and hermit install directories
- Denies writes to lockfiles (`package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`, `Gemfile.lock`, `Cargo.lock`, `poetry.lock`, `uv.lock`)

**Note:** Local installs (e.g., `npm install` into `node_modules/`) are blocked by the guard but not by the sandbox profile — project writes are allowed by `base.sb`. The guard is the primary defense for local installs; this profile provides defense-in-depth for global/system installs.

---

## gui-app

Enables macOS GUI app launches while keeping child processes inside the BlastShield sandbox. BlastShield auto-adds this profile when it detects `open /path/to/App.app`.

| Allowed | Why |
|---------|-----|
| GUI app bundle reads | Locate and execute app bundle binaries |
| Launch Services URL/document opens | External links and "open in browser" actions |
| WebKit sandbox extension issuance | Embedded auth/UI web views |
| Power registration | Normal sleep/wake notification setup |
| Metal/CoreAnimation/IOSurface GPU access | Metal-backed GUI rendering, including Zed |
| `~/Library/Application Support`, `~/Library/Caches`, `~/Library/Preferences`, `~/Library/Logs` writes | Normal per-user app state and logs |

For GUI app launches, BlastShield also keeps runtime guards ahead of user shell paths, even when the app rebuilds `PATH` through a login shell. In interactive terminals, GUI app logs are streamed until the app exits or you press `Ctrl-C`.

**Auto-detection trigger:** any `.app` bundle passed through `open`

## conductor-app

Supports Conductor as a first-class GUI app launch target. BlastShield auto-adds this profile when the app bundle identifier is `com.conductor.app`.

| Allowed | Why |
|---------|-----|
| `~/conductor/workspaces` writes | Conductor agents edit workspace files |
| `~/conductor/repos` writes | Conductor manages root checkouts and shared repo state |
| `~/.conductor` writes | Conductor user settings and local app state |

The Conductor profile intentionally allows full writes under those managed roots so `git worktree` can create new workspaces from repos that track project metadata such as `.idea`, `.vscode`, or `.mcp.json`. Use explicit profiles or a custom profile when a Conductor session needs stricter write policy.

**Auto-detection trigger:** `.app` bundle with `CFBundleIdentifier = com.conductor.app`

See the [Conductor guide](../conductor/) for the supported launch workflow.

---

## Profile Loading Order

Profiles are loaded in this order:

1. `base` — always (deny-by-default foundation)
2. `secrets` — always (credential and SSH key protection)
3. GUI compatibility profiles — `gui-app` for `.app` bundles, plus `conductor-app` for Conductor
4. Auto-detected profiles — based on project directory contents
5. Explicitly specified profiles — via `-p` flag

For GUI app launches, `secrets` is skipped and project profile auto-detection is skipped. Explicit profiles still apply.

All deny rules from all profiles are enforced. Allow rules must pass every profile's checks. This means adding more profiles can only make the sandbox **more restrictive**, never less.
