# BlastShield Runbook

Operational notes for maintainers.

## Cutting a Release

Releases are intentional. Everyday pushes to `master` do not publish a
tarball, GitHub release, or Homebrew tap update.

Use one of:

- **Tag:** create and push a `vMAJOR.MINOR.PATCH` tag. The workflow packages
  that version (updating the in-tree `readonly VERSION` for the tarball if
  needed). Commit the matching `VERSION` on `master` before tagging if you
  want the branch and the release to stay in sync.
- **Actions UI:** run the Release workflow (`workflow_dispatch`) from
  `master`. That path increments the patch version, commits it, tags, and
  publishes.

Both paths run CI first in the same workflow, then keep the existing
packaging, checksum, GitHub release, and Homebrew tap dispatch steps.

Existing v0.1.11–v0.1.20 GitHub releases were published as prereleases.
Intentional releases from this workflow are latest releases so
`/releases/latest` resolves. Older prereleases are left as-is.

## Homebrew Tap Token

BlastShield releases update the Homebrew formula by dispatching the
`update-formula.yml` workflow in `cdrxyz/homebrew-tap`. The BlastShield release
workflow authenticates that dispatch with the `HOMEBREW_TAP_REPO_TOKEN`
repository secret in `cdrxyz/blastshield`.

### Required Token Scope

Create a fine-grained personal access token with:

- Token name: `blastshield-homebrew-tap-dispatch`
- Resource owner: `cdrxyz`
- Repository access: only `cdrxyz/homebrew-tap`
- Repository permissions:
  - Actions: read and write
  - Metadata: read-only, added automatically

Do not grant contents write on the token. The token only triggers the tap
workflow; the tap workflow uses its own `GITHUB_TOKEN` to commit formula
updates inside `cdrxyz/homebrew-tap`.

### Create Or Rotate The Secret

1. Open GitHub personal settings.
2. Go to Developer settings, then Personal access tokens, then Fine-grained tokens.
3. Generate a new token using the scope above.
4. If the organization requires approval or SAML SSO authorization, complete that
   step before using the token.
5. Store the token in the BlastShield repo:

```bash
gh secret set HOMEBREW_TAP_REPO_TOKEN --repo cdrxyz/blastshield
```

6. Verify the secret exists:

```bash
gh secret list --repo cdrxyz/blastshield | rg '^HOMEBREW_TAP_REPO_TOKEN\b'
```

### Smoke Test Dispatch

Run a no-op dispatch against the current placeholder formula values:

```bash
gh workflow run update-formula.yml \
  --repo cdrxyz/homebrew-tap \
  --ref master \
  -f formula=blastshield \
  -f version=0.1.0 \
  -f url=https://github.com/cdrxyz/blastshield/releases/download/v0.1.0/blastshield-0.1.0.tar.gz \
  -f sha256=0000000000000000000000000000000000000000000000000000000000000000
```

Watch the run:

```bash
RUN_ID=$(gh run list --repo cdrxyz/homebrew-tap --workflow update-formula.yml --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch "$RUN_ID" --repo cdrxyz/homebrew-tap --exit-status
```

Expected result: the workflow succeeds and prints that the formula is already up
to date.

### Expiration Checklist

Before the token expires:

1. Create a replacement fine-grained token with the same scope.
2. Replace `HOMEBREW_TAP_REPO_TOKEN` in `cdrxyz/blastshield`.
3. Run the smoke test dispatch.
4. Revoke the old token from GitHub personal settings.
