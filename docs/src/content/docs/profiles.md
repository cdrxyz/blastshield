---
title: Profiles
description: All 8 BlastShield profiles — base, secrets, terraform, gcloud, aws, azure, kubectl, gh — and their blocked/allowed operations.
---

## Profile System

Profiles are [SBPL](https://reverse.put.as/wp-content/uploads/2011/09/Apple-Sandbox-Guide-v1.0.pdf) (Seatbelt Profile Language) files in `profiles/`. They compose by **intersection** — every deny rule from every loaded profile is enforced.

### Built-in Profiles

| Profile | Always Loaded | Purpose |
|---------|:---:|---------|
| `base` | ✅ | Minimum viable sandbox: deny-all default, project writes, system reads |
| `secrets` | ✅ | Protect SSH keys, cloud creds, browser data, shell init files |
| `terraform` | Auto | State file protection, backend config locks, credential denial |
| `gcloud` | Auto | GCP credential protection, SA key denial, ADC protection |
| `aws` | Auto | AWS credential protection, SSO cache denial, state locks |
| `azure` | Auto | Azure credential protection, MSAL cache denial, ARM protection |
| `kubectl` | Auto | Kubeconfig write protection, SA token denial, Helm lock protection |
| `gh` | Auto | GitHub auth protection, workflow file protection, CODEOWNERS locks |

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

Prevents destruction of Terraform infrastructure by blocking access to state files and backend configurations.

| Blocked | Allowed |
|---------|---------|
| `terraform destroy` | `terraform plan` |
| `terraform apply -destroy` | `terraform apply` (create/update) |
| State file writes | `terraform init, fmt, validate` |
| Backend config writes | `terraform show, output, state list` |
| Provider replacement | `terraform import, taint` |

**Auto-detection trigger:** `*.tf` files in project directory

## gcloud

Protects GCP credentials and prevents destructive gcloud operations.

| Blocked | Allowed |
|---------|---------|
| Credential reads | `gcloud * list/describe` |
| Service account key reads | `gcloud * create/deploy` |
| Application default credentials | `gcloud * get-credentials` |
| ADC writes | `gcloud auth status` |

**Auto-detection trigger:** `.gcloudignore`, `cloudbuild.yaml`, `app.yaml`

## aws

Protects AWS credentials and prevents destructive AWS CLI operations.

| Blocked | Allowed |
|---------|---------|
| `~/.aws/credentials` reads | `~/.aws/config` reads |
| SSO token cache reads | `aws * describe/list/get` |
| State file writes | `aws * create/run/start` |
| CDK/SAM state writes | `aws sts get-caller-identity` |

**Auto-detection trigger:** `serverless.yml`, `template.yaml`, `cdk.json`, `samconfig.toml`

## azure

Protects Azure credentials and prevents destructive Azure CLI operations.

| Blocked | Allowed |
|---------|---------|
| `~/.azure` reads | `az * list/show` |
| SP credential reads | `az * create/deploy` |
| ARM template writes | `az * get-credentials` |
| MSAL token cache | `az account show` |

**Auto-detection trigger:** `azure-pipelines.yml`, `local.settings.json`

## kubectl

Protects Kubernetes cluster access by blocking kubeconfig modifications and service account token access.

| Blocked | Allowed |
|---------|---------|
| Kubeconfig writes | Kubeconfig reads |
| Service account tokens | `kubectl get/describe/logs` |
| Helm chart lock writes | `kubectl apply/exec/port-forward` |
| Namespace manifest writes | `kubectl config use-context` |

**Auto-detection trigger:** `kustomization.yaml`, `Chart.yaml`, `skaffold.yaml`

## gh (GitHub CLI)

Protects GitHub authentication and prevents destructive repository operations.

| Blocked | Allowed |
|---------|---------|
| `hosts.yml` reads | `gh repo list/view/clone` |
| Workflow file writes | `gh pr/issue create` |
| CODEOWNERS writes | `gh release create` |
| Dependabot config writes | `gh auth status` |

**Auto-detection trigger:** `.github/` directory

---

## Profile Loading Order

Profiles are loaded in this order:

1. `base` — always (deny-by-default foundation)
2. `secrets` — always (credential and SSH key protection)
3. Auto-detected profiles — based on project directory contents
4. Explicitly specified profiles — via `-p` flag

All deny rules from all profiles are enforced. Allow rules must pass every profile's checks. This means adding more profiles can only make the sandbox **more restrictive**, never less.
