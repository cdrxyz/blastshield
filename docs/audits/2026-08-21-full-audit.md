# BlastShield full repository audit

**Date:** 2026-08-21
**Scope:** Read-only investigation of the repository as of `v0.1.20` (`1ac947b` on `master`). No product, profile, guard, test, or CI behavior was changed in this pass.
**Method:** Direct review of `blastshield`, `helpers/blastshield-guard`, all `profiles/*.sb`, `tests/test-runner.sh`, GitHub Actions workflows, completions, docs, and public GitHub release metadata.

This document is an independent audit. Prior hypotheses were treated as claims to verify, not as facts.

---

## Executive summary

BlastShield is a small, focused, beta macOS tool with a coherent two-layer story: Seatbelt profiles as a kernel filesystem boundary, plus PATH wrappers that classify cloud/package CLI subcommands. The repo is readable, the threat model is mostly honest in the whitepaper, and several real agent-compat issues (Grok/Claude/Codex state, Conductor, Hermit shims, GUI login-shell PATH) have regression tests that run on `macos-latest` against real `sandbox-exec`.

What is **not** solid is the gap between the safety claim and the enforcement. The product pitch is that agents cannot run destructive cloud CLI commands even with `--dangerously-skip-permissions`. In the current code:

- Layer 2 (guard) can be bypassed by ordinary flag ordering, by rewriting its own wrappers in `/tmp`, by full paths, or by calling APIs/`git`/`tofu`/`curl` instead of a wrapped CLI name.
- Layer 1 (Seatbelt) does **not** compose by intersection. Apple `sandbox-exec` is last-match-wins. Later profiles can and do reopen access that earlier profiles denied. GUI launches also drop the `secrets` profile entirely.
- The filesystem denies that the docs treat as the hard boundary (SSH keys, AWS/GCP/Azure creds, tfstate, lockfiles, workflows) are almost untested.
- Every push to `master` auto-cuts a **prerelease** and dispatches Homebrew. GitHub `/repos/cdrxyz/blastshield/releases/latest` returns **404** because no release is marked latest.

The most urgent work is not a refactor. It is: (1) make the guard parser fail closed, (2) stop the sandboxed process from being able to rewrite its own wrappers, (3) tell the truth about profile composition and stop later profiles from silently undoing `secrets`, (4) add deny-path fixtures for the advertised hard boundary, and (5) stop treating every `master` push as a public prerelease.

---

## Hypothesis verification

These were non-binding hypotheses from a prior review. Independent verification:

| Hypothesis | Verdict | Notes |
|---|---|---|
| Every push to `master` auto-cuts a public prerelease and updates Homebrew; all releases are prerelease so `/releases/latest` 404s | **Confirmed** | `.github/workflows/release.yml` runs on every `master` push (except the self-emitted `chore: release v… [skip release]` commit), sets `prerelease: true`, and dispatches `cdrxyz/homebrew-tap`. All of `v0.1.11`–`v0.1.20` are prereleases. `GET https://api.github.com/repos/cdrxyz/blastshield/releases/latest` returns HTTP 404. |
| CI test + profile lint run on `macos-latest` and do hit real `sandbox-exec`, but claimed filesystem denies in `secrets.sb` / `terraform.sb` / `install.sb` / `gh.sb` have no test fixtures | **Confirmed, with one narrow exception** | `ci.yml` `test` and `lint-profiles` both use `macos-latest` and invoke `sandbox-exec`. Integration tests exercise agent-state write allows/denies (Codex/Claude/Grok/Gradle) and one `gh` `hosts.yml` read in a GUI fixture. There are **no** fixtures that attempt to read SSH keys, AWS/GCP/Azure creds, kubeconfig, or to write tfstate, lockfiles, or `.github/workflows`. |
| Docs, `--help`, completions, profile comment headers, and `helpers/blastshield-guard` allow/block tables disagree (`brew upgrade`, `gem update`, `cargo publish`, `gh release create`, `DESTRUCTIVE_COMMANDS` vs `READONLY_PATTERNS`/`MUTATING_PATTERNS`) | **Confirmed** | See Medium finding on policy-source drift. `DESTRUCTIVE_COMMANDS` does not exist in the current guard. |
| Missing `-p` profile is a warning not a hard fail; `--clean-env` skips the GUI launcher path; guard wrappers bake the real binary path at install time | **Confirmed** | `assemble_profile` warns and `continue`s; `--clean-env` always calls `run_sandboxed`, never `run_sandboxed_gui_app`; wrappers `exec` a path captured by `command -v` at install time. |

---

## Findings

### Critical

#### C1. Guard treats boolean flags as consuming the next word, so mutating subcommands can pass through

**Why it matters.** This is a Layer 2 fail-open on the exact commands BlastShield exists to stop. An agent does not need a full path or a clever bypass. `terraform --auto-approve apply` is enough.

**Evidence.** `get_subcommand` in `helpers/blastshield-guard` skips any `-*` token and, if the next token does not start with `-`, skips that too:

```134:138:helpers/blastshield-guard
            -*)
                # Flag, skip it and possibly its argument
                if [[ $((i + 1)) -lt ${#args[@]} ]] && [[ "${args[$((i+1))]}" != -* ]]; then
                    ((i++))
                fi
```

For `terraform --auto-approve apply`, `--auto-approve` eats `apply`. `get_subcommand` returns empty. Both `is_readonly` and `is_mutating` then return false on empty input:

```276:276:helpers/blastshield-guard
    [[ -z "$subcmd" ]] && return 1
```

```299:299:helpers/blastshield-guard
    [[ -z "$subcmd" ]] && return 1
```

The wrapper only calls `require_auth` when `is_mutating` is true, then `exec`s the real binary. Empty subcommand ⇒ not mutating ⇒ pass-through.

The same shape works for `npm -g install`, `brew --debug upgrade` (already allowlisted; see H6), and any other boolean flag immediately before a subcommand. Tests only cover the safe order (`npm install -g react`, `terraform apply` with no leading flag). There is no `check` or integration case for flag-before-subcommand.

**Suggested direction.** Parse flags with an allowlist of known value-taking options per CLI, or treat “no recognized subcommand” as mutating (fail closed) for guarded CLIs. Add regression checks for `terraform --auto-approve apply`, `terraform apply --auto-approve`, `npm -g install`, and `aws --profile x s3 rb …`.

---

### High

#### H1. Sandboxed processes can rewrite Layer 2 wrappers because they live under a writable temp dir

**Why it matters.** The docs call the sandbox the hard boundary and the guard a speed bump. The speed bump is stored in a directory the sandbox explicitly allows the agent to write.

**Evidence.** Runtime wrappers are created under `${TMPDIR:-/tmp}/blastshield.guard.XXXXXX` (`blastshield` `setup_runtime_guards`, lines 389–396) and that directory is prepended to `PATH`. `profiles/base.sb` allows writes to `_TMPDIR`, `/private/tmp`, and `/var/folders` (lines 36–38). An agent can overwrite `$PATH`'s first `terraform`/`aws`/`kubectl` script with `exec /real/bin/terraform "$@"` and never hit `is_mutating` again.

The assembled Seatbelt profile is also a temp file, but `sandbox-exec` loads it at start, so rewriting it is not a live escape. The wrappers are re-executed on every CLI invocation, so rewriting them is a live escape of Layer 2.

GUI cleanup (`run_sandboxed_gui_app` lines 343–356) keeps that temp dir alive for the life of the app, which is the right lifetime and the wrong write policy.

**Suggested direction.** Install wrappers on a directory the assembled profile denies for `file-write*`, or add an explicit deny for `BLASTSHIELD_TMP_GUARD_DIR` after substitution. Treat wrapper integrity as part of Layer 1, not an honor-system PATH trick.

#### H2. Profile composition is last-match-wins, not intersection; later profiles can reopen denied paths

**Why it matters.** The whitepaper calls monotonic restriction a “critical safety property.” The implementation and CI comments say the opposite. Operators who add `-p kubectl` or a custom profile can silently undo `secrets`.

**Evidence.** Docs claim intersection:

- `docs/src/content/docs/whitepaper.md` lines 80–81, 121–123
- `docs/src/content/docs/profiles.md` lines 14, 261
- `docs/src/content/docs/architecture.md` line 63
- `docs/src/content/docs/getting-started.md` line 349

CI says last-match-wins:

```102:103:.github/workflows/ci.yml
              # Compose: base.sb + this profile (sandbox-exec applies last-match-wins)
```

The assembler concatenates profiles in order (`assemble_profile`, `blastshield` lines 255–274), stripping each file’s `(deny default)` so only the first one remains. Later `(allow …)` rules are appended after earlier `(deny …)` rules.

Concrete widenings already in-tree:

- `profiles/secrets.sb` lines 68–70 deny read/write of `_HOME/.kube`.
- `profiles/kubectl.sb` lines 48–49 then **allow** kubeconfig reads.
- `profiles/conductor-app.sb` is an allow-only companion that opens `~/conductor/workspaces`, `~/conductor/repos`, and `~/.conductor` after `base` has denied writes outside `_PROJECT_DIR`.
- `profiles/gui-app.sb` re-allows specific `iokit-open-*` after `base` `(deny iokit-open)`.
- User profiles from `~/.config/blastshield/profiles/` are resolved the same way and, if listed last, can allow anything previously denied.

`blastshield --help` is closer to the truth (“Later profiles can narrow earlier ones”) but still does not say later profiles can also widen.

**Suggested direction.** Document last-match-wins as the real model. If monotonic restriction is the desired property, emit denies after allows (or generate a single normalized policy). Add a composition test: load `secrets` then `kubectl` and assert kubeconfig read is still denied *or* explicitly document the punch-through as intentional and test that.

#### H3. GUI / Conductor path drops `secrets` and project auto-detect; Conductor workspaces are a weaker sandbox

**Why it matters.** A primary documented workflow is `blastshield open /Applications/Conductor.app`. Child agents inherit a sandbox that can read SSH keys, cloud creds, and kubeconfig, and can write git hooks inside Conductor workspaces.

**Evidence.** On `.app` launch, `blastshield` removes `secrets` from the default profile list (lines 622–634) and skips `detect_cloud_profiles` (lines 644–648). `conductor-app.sb` allows writes under `~/conductor/workspaces` and `~/conductor/repos` with none of `base.sb`’s `_PROJECT_DIR` denies (`.git/hooks`, `.git/config`, `.vscode`, `.idea`, `.mcp.json`). `_PROJECT_DIR` is the launch CWD, not the workspace the agent later edits.

Docs and changelog acknowledge the checkout compatibility tradeoff (`v0.1.14`) and tell users to pass explicit `-p` profiles. The README / getting-started Conductor examples do not include `-p secrets` or equivalent. Tests cover workspace writes and “GUI skips auto-detected `gh`”; they do not cover “GUI can read `~/.ssh/id_rsa`” or “Conductor workspace `.git/hooks` is writable.”

**Suggested direction.** Treat GUI mode as a distinct, weaker profile set in every user-facing page. Consider a `conductor-app` deny list for hooks/MCP/env even if `.idea`/`.vscode` must remain writable. Default-recommend `blastshield -p gui-app -p secrets …` if that is still compatible, or add a `gui-secrets` companion that blocks the highest-value credential paths without breaking `gh` startup.

#### H4. `(allow lsopen)` plus unrestricted `process-exec` is a sandbox-escape class, not just OAuth

**Why it matters.** Layer 1 only binds the process tree `sandbox-exec` starts. Launch Services can start a new, unsandboxed app. That voids both layers for any follow-on commands the user or agent runs there.

**Evidence.** `profiles/base.sb` lines 118–124 allow `lsopen` so CLI agents can open a browser. `profiles/gui-app.sb` does the same (line 24). `base.sb` also `(allow process-exec (subpath "/"))` (line 108). The integration suite asserts `open "https://example.com"` succeeds (`tests/test-runner.sh` lines 807–814). There is no test that `open -a Terminal`, `open /System/Applications/Utilities/Terminal.app`, `launchctl`, or `osascript` stays inside the sandbox.

This was added in `v0.1.20` to fix Grok/Claude OAuth. The compatibility fix is real; the policy cost is not documented as a sandbox escape.

**Suggested direction.** Document this as a known escape. Investigate whether SBPL can allow URL opens without app-bundle opens. Test `open -a Terminal` / `launchctl submit` and decide whether those must fail.

#### H5. Layer 1 does not stop authenticated cloud mutation when credentials are not files under the denied paths

**Why it matters.** The README and getting-started lead with “kernel-level protection against `terraform destroy` / `aws s3 rb` / `kubectl delete`.” Seatbelt cannot see argv. If the CLI can authenticate without reading a denied file, Layer 1 will not stop the mutation. Layer 2 is then the only control — and it is bypassable (C1, H1, full path, non-wrapped tools).

**Evidence.**

- Network inbound and outbound are allowed (`profiles/base.sb` lines 113–116).
- Keychain / credential helpers are an acknowledged whitepaper gap.
- `--clean-env` is opt-in and still preserves `SSH_AUTH_SOCK` (`blastshield` lines 702–715), so git+SSH and some helpers keep working.
- Remote Terraform backends do not need a local `.tfstate` write. `terraform.sb` only denies local state/lock/plan paths. `terraform apply` against a remote backend with env/instance/Keychain creds is a Layer 1 miss.
- Direct API use (`curl`, `python`, `node`) is unguarded. `gradle` is explicitly unguarded.
- `tofu` (OpenTofu) is not a guarded CLI name. `git` is not guarded (`git push --force` is allowed). `docker` / `pulumi` / `sam` / `cdk` / `flyctl` / `vercel` / `uv` / `poetry` / `bun` / `go` are not guarded.
- GCP Application Default Credentials at `~/.config/gcloud/application_default_credentials.json` are denied in `gcloud.sb` (lines 57–58) but **not** in always-on `secrets.sb` (which only denies `credentials/` and `access_tokens/`). Without a GCP indicator file, ADC remains readable.
- Project `.env` files are readable/writable via `_PROJECT_DIR`. `secrets.sb` only denies `_HOME/.env` and a few home variants (lines 99–102).

The whitepaper already rates network exfiltration and Keychain as remaining vulnerabilities. The gap is that marketing/docs still describe Layer 1 as blocking those destructive commands, and that several high-value credential paths are missing from the always-on profile.

**Suggested direction.** Narrow the public claim to “blocks credential-file reads and some state writes; command filtering is best-effort.” Move ADC and common token caches into `secrets.sb`. Decide whether project `.env` is in or out of scope and test it. Add `tofu` as an alias of the terraform guard, or document the omission.

#### H6. Guard allowlist is internally inconsistent and allow-lists real mutations

**Why it matters.** The guard is default-deny *except* where `READONLY_PATTERNS` over-approves. Several of those approvals contradict the docs and the mutating table.

**Evidence.** `is_readonly` is checked first (`is_mutating` lines 302–304). First-word / last-word matching then widens further (`matches_pattern` lines 189–213).

| Command | Code | Docs / headers |
|---|---|---|
| `brew upgrade` / `brew update` | `READONLY_PATTERNS` includes `update,upgrade` (`helpers/blastshield-guard` line 50) | `architecture.md` lists `brew upgrade` as destructive; `guard.md` brew table omits it |
| `gem update` | readonly includes `update` (line 51); mutating has `update_*` only | `architecture.md` lists `gem update` as destructive; `guard.md` puts `update *` on the mutating side |
| `cargo publish` | readonly includes `publish,owner` (line 52); mutating has `publish_*` | `guard.md` cargo table lists `publish` under Read-Only |
| `aws s3 cp …` | readonly `s3_cp*` (line 41) matches uploads as well as downloads | docs say “s3 cp (download)” |
| `gcloud config set …` / `gcloud auth login` | first word `config` / `auth` matches readonly `config` / `auth` (line 40) | mutating table lists `set`; profile header treats auth login as out of scope |
| `gh release create` | **not** in readonly ⇒ blocked by default deny | `profiles/gh.sb` lines 25–29 and `profiles.md` / `getting-started.md` list `gh release create` as allowed |
| `gh issue create`, `gh pr create`, `gh secret set`, `gh workflow run` | blocked by default deny | `gh.sb` header says create/comment/secret set/workflow run are allowed |

`lambda_invoke*` is also readonly; invoke is not a read. No tests exist for any row in this table except the documented create/delete happy paths.

**Suggested direction.** Make `READONLY_PATTERNS` the single source of truth, generate docs/help from it, and remove first-word matching or restrict it to known verb-final CLIs with an explicit verb list. Flip `brew upgrade`, `gem update`, `cargo publish`, and `s3_cp*` (split upload vs download, or block `cp`) to fail closed unless a human explicitly wants them.

#### H7. Claimed filesystem hard-boundary denies are almost untested

**Why it matters.** CI can stay green while `secrets.sb` / `terraform.sb` / `install.sb` / `gh.sb` stop denying the paths the product advertises. Profile lint only checks `(version 1)`, a `(deny` substring or allow-only marker, no tabs, and that `sandbox-exec` will run `/usr/bin/true`.

**Evidence.** `tests/test-runner.sh` integration coverage for denies is concentrated on agent runtime files (`~/.codex/config.toml`, `~/.claude/settings.json`, `~/.grok/auth.json`, `~/.gradle/gradle.properties`) plus one GUI `hosts.yml` case. There is no fixture that:

- reads `~/.ssh/id_rsa` / `id_ed25519` under `secrets`
- reads `~/.aws/credentials`, ADC, or `~/.azure`
- writes `terraform.tfstate`, `.terraform.lock.hcl`, or `*.tfplan`
- writes `package-lock.json` / `Cargo.lock` / `uv.lock`
- writes `.github/workflows/*.yml`
- writes `_PROJECT_DIR/.git/hooks`

`lint-profiles` in `.github/workflows/ci.yml` (lines 57–132) never opens those paths. A broken regex after `_HOME` substitution would not fail CI.

**Suggested direction.** Add a small fixture home + project for each profile. Assert deny on the paths named in the profile comments. Keep the existing agent-state tests; they are the right shape.

#### H8. Unknown `-p` profile is a warning; the process still starts

**Why it matters.** A typo (`-p terrafrom`) or a Homebrew install missing a file drops that protection and continues. For a safety tool this is fail-open.

**Evidence.**

```257:260:blastshield
            if ! path=$(resolve_profile "$name"); then
                warn "Profile not found: $name (skipping)"
                continue
            fi
```

No test asserts a missing `-p` is fatal. `--help` does not mention the skip behavior.

**Suggested direction.** Hard-fail on missing *explicit* `-p` names. Keep “skip and warn” only for optional auto-detect names, if at all.

#### H9. Every `master` push publishes a prerelease and Homebrew formula; `/releases/latest` 404s; CI is not a release gate

**Why it matters.** A docs-only or failing-test merge still ships a public tarball and can move the Homebrew tap. Consumers and scripts that follow GitHub “latest” get nothing. Supply-chain reviewers cannot pin “the latest stable.”

**Evidence.**

- Trigger: `on.push.branches: [master]` plus `workflow_dispatch` (`.github/workflows/release.yml` lines 3–7).
- Skip logic only suppresses the self-push whose message starts with `chore: release v` **and** contains `[skip release]` (line 12). Regular commits always release.
- Version is `current patch + 1` read from `blastshield` (lines 32–44), independent of changelog intent.
- `prerelease: true` is hardcoded (line 94).
- `v0.1.11`–`v0.1.20` are all prereleases. `GET /repos/cdrxyz/blastshield/releases/latest` → 404.
- Release job does not `needs: [test, lint-profiles]`. CI and release race on the same push.
- Homebrew dispatch uses `HOMEBREW_TAP_REPO_TOKEN` and passes `version`, `url`, and `sha256` computed by this job into `cdrxyz/homebrew-tap` `update-formula.yml` (lines 101–118). The release workflow triggers on `push` to `master` and `workflow_dispatch` only — not `pull_request` — so a fork PR cannot supply those inputs. Residual risk is a `master` push or a manual dispatch shipping a tarball whose checksum the tap then trusts; `RUNBOOK.md` correctly limits the token to Actions write on the tap only. The tap workflow’s trust in those inputs is out of repo and unverified here.
- Actions are tagged (`actions/checkout@v4`, `softprops/action-gh-release@v1`, `peaceiris/actions-gh-pages@v4`), not SHA-pinned.
- `scripts/package-release.py` appends to `dist/checksums.txt` (`"a"`), so a dirty `dist/` can ship extra checksum lines.
- Two near-simultaneous `master` pushes can race the version bump commit.

`AGENTS.md` asks feature commits to use the next changelog version. The release workflow then creates that version automatically. That pairing works only if humans never bump `VERSION` themselves and never merge two releasable commits in one push window.

**Suggested direction.** Release on tag or `workflow_dispatch` only. Mark intended stables as `prerelease: false`. Require the `test` + `lint-profiles` jobs. Pin Actions by SHA. Make checksums a truncate-write. Decide whether Homebrew should move on every beta cut.

#### H10. `gh` profile denies all `.git` writes, which breaks `git commit` in any repo with `.github/`

**Why it matters.** Auto-detect loads `gh` whenever `.github/` exists (this repository included). Agents that are supposed to commit then fail at the kernel, or they work around it by not using BlastShield.

**Evidence.** `profiles/base.sb` denies only `_PROJECT_DIR/.git/hooks` and `.git/config` (lines 61–62). `profiles/gh.sb` lines 66–67 deny the entire `_PROJECT_DIR/.git` subpath. Auto-detect trigger is `[[ -d "$dir/.github" ]]` (`blastshield` lines 211–214). No test runs `git add` / `git commit` under auto-detect.

**Suggested direction.** Keep the hook/config denies; drop the blanket `.git` deny, or replace it with denies for `hooks`, `config`, and maybe `COMMIT_EDITMSG` if that is the real goal. Add a commit fixture.

---

### Medium

#### M1. `--clean-env` never uses the GUI launcher path

**Why it matters.** `blastshield -c open App.app` still rewrites the `.app` command and may set `ZDOTDIR`, but then runs `env -i … run_sandboxed` (foreground, blocking, no detach, no GUI temp-dir lifetime). Users who follow “always use `-c`” on Conductor get a different process model than the documented GUI path.

**Evidence.** `blastshield` lines 699–732: `clean_env` is a separate branch that always calls `run_sandboxed`. `run_sandboxed_gui_app` is only in the `else`. No test covers `-c` + `open *.app`.

**Suggested direction.** If `-c` + GUI is supported, thread `env -i` into `run_sandboxed_gui_app`. If not, hard-error with a message.

#### M2. Persistent (and runtime) wrappers bake `command -v` at install time

**Why it matters.** After `brew upgrade terraform` or a Hermit shim retarget, the wrapper still `exec`s the old path. That can run a stale binary, or fail closed if the path disappeared. The wrapper text also leaks the real path to any agent that `cat`s `$(which terraform)` — a documented full-path bypass with a convenient treasure map.

**Evidence.** `install_guards` lines 385–410 write `exec "$real_binary" "$@"`. `find_real_binary` exists (lines 356–365) but wrappers do not call it. Runtime install is quiet and per-launch, so staleness is mostly a persistent-wrapper problem; the leaked path is a runtime problem too.

**Suggested direction.** Resolve the real binary at exec time from a filtered `PATH`, or `exec -a` via a denied-write helper. Do not embed the absolute path in a file the sandbox can read.

#### M3. Policy is copied by hand across nine sources and has already drifted

**Why it matters.** Users and contributors cannot know what is actually blocked. FAQ still tells people to edit a `DESTRUCTIVE_COMMANDS` associative array that does not exist.

**Evidence.** Current sources of “what is blocked”:

1. `READONLY_PATTERNS` / `MUTATING_PATTERNS` in `helpers/blastshield-guard` (the only runtime source)
2. `blastshield-guard` `help` text (lines 508–543)
3. `docs/src/content/docs/guard.md` tables
4. `docs/src/content/docs/architecture.md` “Guarded Commands” table (delete-only for cloud CLIs; lists `brew upgrade` / `gem update` as destructive)
5. `docs/src/content/docs/profiles.md` and `getting-started.md` allow/block tables
6. Comment headers in `profiles/*.sb` (especially `gh.sb` vs guard)
7. FAQ (`docs/src/content/docs/faq.md` line 184: `DESTRUCTIVE_COMMANDS`)
8. Completions (`completions/blastshield.bash`, `blastshield.zsh`, `_blastshield`): profiles stop at `gh` (missing `install`, `gui-app`, `conductor-app`); flags omit `--no-guard` and `--detach`; agents omit `grok`
9. `blastshield --help` OPTIONS “Built-in:” line omits `install`, `gui-app`, `conductor-app` (lines 527–528). The PROFILES section of the same help text already lists those three (lines 558–563).

`Pipfile.lock` is listed as denied in `architecture.md` and the whitepaper; `install.sb` does not deny it (it does deny `poetry.lock` and `uv.lock`).

**Suggested direction.** Generate guard help + a docs fragment from the pattern tables. Add a CI check that FAQ/architecture tables do not mention `DESTRUCTIVE_COMMANDS` and that completion profile lists match `profiles/*.sb`.

#### M4. Broad deny regexes can hide project files or fail to match after substitution

**Why it matters.** Over-broad denies break agents on legitimate files; under-escaped literals in regexes miss the intended files.

**Evidence.**

- `profiles/aws.sb` lines 81–82: `#" .*aws.*credentials.* "` and `#" .*aws.*config.*\.json$ "` can deny project docs/fixtures whose names contain those substrings.
- `profiles/gh.sb` lines 55–57: `#" .*github.*token.* "` / `#" .*gh_token.* "` similarly.
- `profiles/gcloud.sb` lines 63–66: `#" .*service-account.*\.json$ "` can deny checked-in terraform/GCP examples.
- `profiles/gui-app.sb` line 136: `(deny file-write* (regex "^/Users/(?!_HOME)"))` uses a quoted pattern (not SBPL `#"…"`), a PCRE lookahead, and substitutes `_HOME` with a full path like `/Users/name`, producing `^/Users/(?!/Users/name)`. That does not mean “other users’ homes.” It may be a no-op or an over-deny depending on the Seatbelt regex engine. Untested.
- `_HOME` / `_PROJECT_DIR` are `sed` replacements. Regex metacharacters in usernames or paths are not escaped for SBPL regex.

**Suggested direction.** Prefer `literal` / `subpath` for home credential files. If regexes stay, escape for SBPL and add fixtures. Rewrite or drop the gui-app “other users” rule.

#### M5. `detect_cloud_clis` contains a second, incomplete GUI rewriter that `--status` can run

**Why it matters.** Status output and launch policy can diverge. The function mutates `command_args` / `extra_profiles` as a side effect even though its documented job is “list CLIs on PATH.”

**Evidence.** `blastshield` lines 151–178 loop CLIs, then (if `command_args` looks like `open *.app`) rewrite the command and maybe append `gui-app`. `show_status` (lines 439–443) calls this. The production GUI rewrite (lines 591–620) also adds `conductor-app` and sets `gui_app_launch`; the copy inside `detect_cloud_clis` does not. `auto_detect` is assigned without `local` (line 472).

**Suggested direction.** Make detection pure. Keep one GUI rewrite in `main`.

#### M6. Guard matcher uses `xargs` and first/last-word globs; `((i++))` under `set -e` is a bash footgun

**Why it matters.** macOS `/bin/bash` is 3.2; Homebrew bash is 5.x. Behavior of `set -e` + `((i++))` when `i` is 0 differs. `xargs` will also mangle patterns that look like options.

**Evidence.** `matches_pattern` line 178: `pattern=$(echo "$pattern" | xargs)`. `get_subcommand` uses standalone `((i++))` inside a `set -euo pipefail` script. `PATH=… | grep -v "$GUARD_DIR"` (lines 361, 386) treats the directory as a regex (`.` matches any character) and can drop unrelated PATH entries.

**Suggested direction.** Use `i=$((i + 1))`, trim without `xargs`, and filter PATH with `case` / string prefix, not `grep` regex.

#### M7. Docs-site deploy and PR previews write to `gh-pages` with `keep_files: true`; Actions unpinned

**Why it matters.** Stale preview directories and a compromised Actions tag are a docs/supply-chain issue, not an agent-sandbox issue, but this is a public safety product.

**Evidence.** `.github/workflows/deploy.yml` and `pr-preview.yml` use `peaceiris/actions-gh-pages@v4` with `keep_files: true`. Preview cleanup only runs on PR close. No `CODEOWNERS`, `SECURITY.md`, Dependabot, or pull-request template.

**Suggested direction.** Pin SHAs, add `SECURITY.md` with a disclosure path, and consider deleting stale `pr-preview/*` on a schedule.

---

### Low

#### L1. Completions and `--help` lag the real CLI

`--no-guard`, `--detach`, `install`, `gui-app`, `conductor-app`, and `grok` are missing from completions. The `--help` OPTIONS “Built-in:” line is incomplete (terraform/gcloud/aws/azure/kubectl/gh only); the PROFILES section already lists `install`, `gui-app`, and `conductor-app`. `completions/blastshield.zsh` and `completions/_blastshield` are identical.

#### L2. Leftover `cloudseal` naming in always-on profiles

`profiles/base.sb` line 1 and `profiles/secrets.sb` line 1 still say “cloudseal.” Confusing for anyone tracing policy provenance.

#### L3. Release commit message embeds literal `\n`

`.github/workflows/release.yml` line 71 uses `"chore: release v…\n\n[skip ci] [skip release]"` inside a bash double-quoted `-m`. Bash does not interpret `\n` there. History shows messages like `chore: release v0.1.20\n\n[skip ci] [skip release]`. The skip still works because both substrings are present; it is sloppy and makes `git log --oneline` noisy.

#### L4. Profile lint treats non-syntax `sandbox-exec` failures as warnings

`.github/workflows/ci.yml` lines 115–123: if `sandbox-exec` fails without matching `syntax|parse|…`, the job continues. A broken profile that fails for “operation not permitted” during `/usr/bin/true` can pass lint.

#### L5. `network-inbound` is allowed with no documented reason

`profiles/base.sb` line 116. Agents can listen on ports. Whitepaper discusses egress, not inbound.

#### L6. Whitepaper PDF can drift from `whitepaper.md`

`docs/public/blastshield-whitepaper.pdf` is a generated artifact. `scripts/generate-whitepaper-pdf.py` duplicates claims (including `Pipfile.lock`). There is no CI check that the PDF was regenerated.

#### L7. `--status` reports CLIs on PATH, not the profiles that will actually load

`detect_cloud_clis` lists binaries; `detect_cloud_profiles` lists directory indicators. A machine with `terraform` installed but no `*.tf` files shows the CLI and not the profile. Easy to misread as “terraform protection is on.”

---

### Nit

#### N1. Large single-file shell / test suite

`blastshield` (~735 lines), `helpers/blastshield-guard` (~570), `tests/test-runner.sh` (~1158) are still followable but concentrate policy, argument parsing, GUI process management, and tests in ways that make review error-prone. Not a reason to rewrite; a reason to extract generated policy tables and a dedicated deny-fixture helper.

#### N2. Duplicate GUI `.app` detection

The same `open *.app` block appears in `main` and `detect_cloud_clis`. One should die.

#### N3. `find … -perm +111` is a deprecated find primary

`resolve_app_bundle` line 124. Prefer `-perm -111` / `-perm /111` depending on the macOS `find` in use.

---

## What's working well

- **Clear two-layer story, mostly honestly caveated.** The whitepaper’s remaining-vulnerabilities section (network exfil, Keychain, PATH bypass, `sandbox-exec` deprecation, package-manager evasion) is the most accurate document in the repo. Guard docs already say Layer 2 is a speed bump.
- **Runtime guard injection is the right default.** Temporary wrappers + `BLASTSHIELD_GUARD_MODE=block` (no sudo prompt inside the agent) matches “the agent plans, you execute.” Persistent wrappers for humans are separate.
- **Hermit / repo-local shim coverage exists and is tested.** Integration tests in `tests/test-runner.sh` (lines 692–754) and `tests/fixtures/hermit-project/` show `terraform apply` / `gcloud … delete` blocked when the shim is first on `PATH` and invoked by name.
- **Agent runtime-state work is real.** Codex, Claude, Grok, and Gradle have paired allow/deny integration tests. That is the right test shape for Seatbelt policy.
- **GUI/Conductor compatibility was earned, not faked.** WebKit extension issuance, power registration, Metal, Library Logs, CFBundleExecutable resolution, login-shell `PATH` guard precedence, and Conductor workspace writes all have tests. `conductor-app` is explicitly marked `blastshield: allow-only-profile` so lint does not demand a deny.
- **CI hits real `sandbox-exec`.** `macos-latest` for tests and profile lint is the correct runner for a Seatbelt product. Docs build is a separate Ubuntu job with a page-count sanity check.
- **Homebrew tap token is documented with least-privilege intent.** `RUNBOOK.md` specifies a fine-grained PAT, Actions write only, no contents write, plus rotation and a smoke-test dispatch.
- **Fail closed when `sandbox-exec` is missing.** Both `run_sandboxed` and `run_sandboxed_gui_app` `die` if the binary is absent. Linux is not given a fake “guard-only blastshield” that would imply kernel enforcement.
- **Contributor rule is simple and enforced socially.** `AGENTS.md` requires every non-release commit to update `docs/src/content/docs/changelog.md` with the next release number. That file is the contributor changelog this audit updates. This write-up does not treat it as a published product-policy Starlight page (unlike `guard.md` / `profiles.md` / architecture).
- **Beta banner is present.** README, getting-started, and the docs `BetaBanner` do not pretend this is finished.

---

## Recommended priority if we only fix 3–5 things next

1. **C1 — Guard parser fail-closed.** Boolean flags must not swallow subcommands; empty/unknown subcommand on a guarded CLI must be mutating. This is the highest-leverage correctness bug and is unit-testable without Seatbelt.
2. **H1 — Stop the sandbox from writing the wrapper directory.** Until this is true, treat Layer 2 as agent-optional.
3. **H6 + generated policy tables — Fix the allowlist holes and the docs drift in one pass.** `brew upgrade`, `gem update`, `cargo publish`, `aws s3 cp` uploads, and `gcloud config`/`auth` first-word matches should not be “read-only.” Generate `guard.md` / `--help` from the tables so `DESTRUCTIVE_COMMANDS` cannot reappear.
4. **H7 + H2 — Deny-path fixtures and an honest composition model.** Test the advertised hard boundary (SSH, AWS creds, ADC, tfstate, lockfiles, workflows). Decide whether `kubectl` may reopen kubeconfig and encode that decision in a test. Hard-fail missing explicit `-p` (H8) in the same sweep if cheap.
5. **H9 — Release only on purpose.** Tag or button; one non-prerelease when you want `/releases/latest`; require CI; pin Actions SHAs. Do this before the next compatibility patch so Homebrew users are not advanced by accident.

H3 (GUI/Conductor weaker sandbox) and H4 (`lsopen` escape) are next-tier threat-model work: document immediately, then decide whether the OAuth/Conductor compatibility trade is still acceptable. Do not expand GUI allowances further until those tests exist.

---

## Out of scope / not found

- No `SECURITY.md`, `CODEOWNERS`, Dependabot, or PR template.
- No Linux/bubblewrap implementation (docs correctly say macOS-only).
- Homebrew formula lives in `cdrxyz/homebrew-tap`, not this repo; tap workflow trust in dispatch inputs was not audited.
- No attempt was made to exploit a live Mac in this environment (Linux VM). Guard fail-open (C1) and composition/docs claims were established from source and public GitHub metadata.
- Seatbelt last-match-wins is the industry-standard reading and matches this repo’s CI comment; it was not re-proven on hardware here.
