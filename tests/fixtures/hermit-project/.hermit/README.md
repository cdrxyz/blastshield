This fixture models a repo with Hermit-managed command shims in `bin/`.

The fake CLIs write their invoked arguments to `HERMIT_MARKER` so integration
tests can verify whether BlastShield allowed the underlying dependency to run.
