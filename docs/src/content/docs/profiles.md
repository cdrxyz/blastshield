---
title: Profiles
description: All 8 BlastShield profiles — base, secrets, terraform, gcloud, aws, azure, kubectl, gh — enforcing read-only cloud access.
---

## Read-Only Philosophy

All cloud profiles enforce a **default-deny** posture for mutations. The AI agent can inspect resources (`list`, `describe`, `get`, `plan`) but cannot modify them. Any mutating operation — `apply`, `deploy`, `create`, `delete`, `update` — requires the user to run it manually.

This is by design: the agent plans, **you** execute.

## Profile System

Profiles are [SBPL](https://reverse.put.as/wp-content/uploads/2011/09/Apple-Sandbox-Guide-v1.0.pdf) (Seatbelt Profile Language) files in `profiles/`. They compose by **intersection** — every deny rule from every loaded profile is enforced.

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
| `gh pr merge/close` | `gh pr list/view/diff/checkout` |
| `gh release delete` | `gh release create/list/view/download` |
| `gh workflow disable/enable` | `gh workflow list/view` |
| `gh run cancel` | `gh issue create/list/view/comment` |
| `gh api -X DELETE/PUT/PATCH` | `gh pr create` |
| Workflow file writes | `gh auth status` |
| CODEOWNERS writes | `gh secret set` |

**Auto-detection trigger:** `.github/` directory

---

## Profile Loading Order

Profiles are loaded in this order:

1. `base` — always (deny-by-default foundation)
2. `secrets` — always (credential and SSH key protection)
3. Auto-detected profiles — based on project directory contents
4. Explicitly specified profiles — via `-p` flag

All deny rules from all profiles are enforced. Allow rules must pass every profile's checks. This means adding more profiles can only make the sandbox **more restrictive**, never less.
