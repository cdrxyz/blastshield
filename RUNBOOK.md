# BlastShield Runbook

Operational notes for maintainers.

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
