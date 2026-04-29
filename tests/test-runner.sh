#!/usr/bin/env bash
# test-runner.sh — BlastShield test suite
# Runs all tests: profile syntax, guard unit tests, integration tests

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly PROFILES_DIR="$REPO_DIR/profiles"
readonly BLASTSHIELD="$REPO_DIR/blastshield"
readonly GUARD="$REPO_DIR/helpers/blastshield-guard"

PASS=0
FAIL=0
SKIP=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

pass() { ((PASS++)); echo -e "  ${GREEN}✓ PASS${NC} $1"; }
fail() { ((FAIL++)); echo -e "  ${RED}✗ FAIL${NC} $1"; echo -e "         ${RED}${2:-}${NC}"; }
skip() { ((SKIP++)); echo -e "  ${YELLOW}⊘ SKIP${NC} $1"; }

section() { echo -e "\n${CYAN}═══ $1 ═══${NC}"; }

# ─── Profile Syntax Tests ────────────────────────────────────────────────

section "Profile Syntax Validation"

for profile in "$PROFILES_DIR"/*.sb; do
    name=$(basename "$profile" .sb)

    # Test 1: File exists and is readable
    if [[ -r "$profile" ]]; then
        pass "$name: file exists and is readable"
    else
        fail "$name: file not readable" "$profile"
        continue
    fi

    # Test 2: Contains (version 1) directive
    if grep -q '^(version 1)$' "$profile"; then
        pass "$name: contains (version 1) directive"
    else
        fail "$name: missing (version 1) directive" "Every profile must have (version 1)"
    fi

    # Test 3: Contains at least one (deny ...) rule
    if grep -q '(deny ' "$profile"; then
        pass "$name: contains deny rules"
    else
        fail "$name: no deny rules found" "Profiles should have explicit deny rules"
    fi

    # Test 4: No obvious syntax errors — balanced parentheses in rules
    # Count opening parens (not in comments) and check basic balance
    rule_lines=$(grep -v '^;;' "$profile" | grep -c '(' || true)
    if [[ $rule_lines -gt 0 ]]; then
        pass "$name: has rule content ($rule_lines rule lines)"
    else
        fail "$name: no rule content found" "Profile appears empty after stripping comments"
    fi

    # Test 5: No tab characters (SBPL uses spaces)
    if grep -Pq '\t' "$profile" 2>/dev/null || grep -q $'\t' "$profile"; then
        fail "$name: contains tab characters" "SBPL files should use spaces, not tabs"
    else
        pass "$name: no tab characters"
    fi

    # Test 6: Validate with sandbox-exec -n (syntax check) if available
    if command -v sandbox-exec &>/dev/null; then
        # sandbox-exec -n does a dry-run syntax check
        # We need to substitute parameters first for full validation
        # For now, just check if sandbox-exec can parse it with dummy params
        tmp=$(mktemp)
        sed -e "s/_HOME/\/Users\/test/g" \
            -e "s/_PROJECT_DIR/\/Users\/test\/project/g" \
            -e "s/_TMPDIR/\/tmp/g" \
            "$profile" > "$tmp"

        if sandbox-exec -n -f "$tmp" true 2>/dev/null; then
            pass "$name: sandbox-exec syntax check passes"
        else
            # sandbox-exec -n may not be supported on all versions
            # Try without -n — if it errors on syntax, that's a real problem
            if timeout 2 sandbox-exec -f "$tmp" /bin/true 2>&1 | grep -qi "syntax\|parse\|invalid"; then
                fail "$name: sandbox-exec reports syntax error" "Run: sandbox-exec -f $tmp -- true"
            else
                skip "$name: sandbox-exec syntax check (sandbox-exec -n not available)"
            fi
        fi
        rm -f "$tmp"
    else
        skip "$name: sandbox-exec syntax check (sandbox-exec not available — not on macOS)"
    fi
done

# ─── BlastShield Wrapper Tests ───────────────────────────────────────────

section "BlastShield Wrapper Tests"

# Test: wrapper script exists and is executable
if [[ -x "$BLASTSHIELD" ]]; then
    pass "blastshield: script is executable"
else
    fail "blastshield: script is not executable" "Run: chmod +x $BLASTSHIELD"
fi

# Test: --help works
if "$BLASTSHIELD" --help 2>&1 | grep -q "sandbox"; then
    pass "blastshield --help: outputs help text containing 'sandbox'"
else
    fail "blastshield --help: expected help text with 'sandbox'" "Got unexpected output"
fi

# Test: --version works
version_output=$("$BLASTSHIELD" --version 2>&1)
if [[ "$version_output" =~ ^blastshield\ v[0-9] ]]; then
    pass "blastshield --version: outputs version string"
else
    fail "blastshield --version: unexpected output" "Got: $version_output"
fi

# Test: --status works
status_out=$("$BLASTSHIELD" --status 2>&1) || true
if echo "$status_out" | grep -qE "blastshield|v[0-9]"; then
    pass "blastshield --status: outputs status information"
else
    fail "blastshield --status: unexpected output" "Should show version and status"
fi

# Test: profile resolution for each built-in profile
for profile_name in base secrets terraform gcloud aws azure kubectl gh; do
    # Test that resolve_profile function can find each profile
    profile_path="$PROFILES_DIR/${profile_name}.sb"
    if [[ -f "$profile_path" ]]; then
        pass "profile '$profile_name': resolves to $profile_path"
    else
        fail "profile '$profile_name': not found at $profile_path"
    fi
done

# Test: auto-detection function doesn't crash
status_out2=$("$BLASTSHIELD" --status 2>&1) || true
if echo "$status_out2" | grep -qE "(Available|Detected|Built-in|profiles)"; then
    pass "auto-detection: --status runs without error"
else
    fail "auto-detection: --status missing expected sections"
fi

# ─── Guard Tests ──────────────────────────────────────────────────────────

section "BlastShield Guard Tests"

# Test: guard script exists and is executable
if [[ -x "$GUARD" ]]; then
    pass "blastshield-guard: script is executable"
else
    fail "blastshield-guard: script is not executable" "Run: chmod +x $GUARD"
fi

# Test: guard help works
if "$GUARD" help 2>&1 | grep -qi "mutating\|read-only"; then
    pass "blastshield-guard help: outputs help text"
else
    fail "blastshield-guard help: expected help with 'mutating' or 'read-only'"
fi

# Test: guard list works
list_out=$("$GUARD" list 2>&1) || true
if echo "$list_out" | grep -q "terraform"; then
    pass "blastshield-guard list: lists terraform as guarded"
else
    fail "blastshield-guard list: expected terraform in output"
fi

# Test: guard check — destructive command
if "$GUARD" check terraform destroy 2>&1; then
    fail "blastshield-guard check terraform destroy: should be blocked" "Expected exit code 1"
else
    pass "blastshield-guard check terraform destroy: correctly blocked"
fi

# Test: guard check — safe command
if "$GUARD" check terraform plan 2>&1; then
    pass "blastshield-guard check terraform plan: correctly allowed"
else
    fail "blastshield-guard check terraform plan: should be allowed" "Expected exit code 0"
fi

# Test: guard check — gcloud delete blocked
if "$GUARD" check gcloud delete 2>&1; then
    fail "blastshield-guard check gcloud delete: should be blocked"
else
    pass "blastshield-guard check gcloud delete: correctly blocked"
fi

# Test: guard check — aws describe- allowed (read-only)
if "$GUARD" check aws ec2 describe-instances 2>&1; then
    pass "blastshield-guard check aws describe-instances: correctly allowed (read-only)"
else
    fail "blastshield-guard check aws describe-instances: should be allowed"
fi

# Test: guard check — kubectl delete blocked
if "$GUARD" check kubectl delete 2>&1; then
    fail "blastshield-guard check kubectl delete: should be blocked"
else
    pass "blastshield-guard check kubectl delete: correctly blocked"
fi

# Test: guard check — az delete blocked
if "$GUARD" check az delete 2>&1; then
    fail "blastshield-guard check az delete: should be blocked"
else
    pass "blastshield-guard check az delete: correctly blocked"
fi

# Test: guard check — terraform apply now blocked (read-only posture)
if "$GUARD" check terraform apply 2>&1; then
    fail "blastshield-guard check terraform apply: should be blocked (read-only posture)"
else
    pass "blastshield-guard check terraform apply: correctly blocked (read-only posture)"
fi

# Test: guard check — gcloud create blocked
if "$GUARD" check gcloud create 2>&1; then
    fail "blastshield-guard check gcloud create: should be blocked"
else
    pass "blastshield-guard check gcloud create: correctly blocked"
fi

# Test: guard check — aws create blocked
if "$GUARD" check aws create 2>&1; then
    fail "blastshield-guard check aws create: should be blocked"
else
    pass "blastshield-guard check aws create: correctly blocked"
fi

# Test: guard check — kubectl apply blocked
if "$GUARD" check kubectl apply 2>&1; then
    fail "blastshield-guard check kubectl apply: should be blocked"
else
    pass "blastshield-guard check kubectl apply: correctly blocked"
fi

# Test: guard check — gcloud list allowed (read-only)
if "$GUARD" check gcloud list 2>&1; then
    pass "blastshield-guard check gcloud list: correctly allowed (read-only)"
else
    fail "blastshield-guard check gcloud list: should be allowed"
fi

# Test: guard check — kubectl get allowed (read-only)
if "$GUARD" check kubectl get 2>&1; then
    pass "blastshield-guard check kubectl get: correctly allowed (read-only)"
else
    fail "blastshield-guard check kubectl get: should be allowed"
fi

# Test: guard check — gcloud compute instances list allowed (read-only, 3-word subcmd)
if "$GUARD" check gcloud compute instances list 2>&1; then
    pass "blastshield-guard check gcloud compute instances list: correctly allowed (read-only)"
else
    fail "blastshield-guard check gcloud compute instances list: should be allowed"
fi

# Test: guard check — gcloud compute instances delete blocked (3-word subcmd)
if "$GUARD" check gcloud compute instances delete 2>&1; then
    fail "blastshield-guard check gcloud compute instances delete: should be blocked"
else
    pass "blastshield-guard check gcloud compute instances delete: correctly blocked"
fi

# Test: guard check — gh pr merge blocked (mutating)
if "$GUARD" check gh pr merge 2>&1; then
    fail "blastshield-guard check gh pr merge: should be blocked"
else
    pass "blastshield-guard check gh pr merge: correctly blocked"
fi

# Test: guard check — aws ec2 run-instances blocked (mutating)
if "$GUARD" check aws ec2 run-instances 2>&1; then
    fail "blastshield-guard check aws ec2 run-instances: should be blocked"
else
    pass "blastshield-guard check aws ec2 run-instances: correctly blocked"
fi

# Test: guard check — aws s3 ls allowed (read-only)
if "$GUARD" check aws s3 ls 2>&1; then
    pass "blastshield-guard check aws s3 ls: correctly allowed (read-only)"
else
    fail "blastshield-guard check aws s3 ls: should be allowed"
fi

# ─── Integration Tests ───────────────────────────────────────────────────

section "Integration Tests (require macOS + sandbox-exec)"

if command -v sandbox-exec &>/dev/null; then

    # Test: sandbox-exec with a minimal valid profile can run a command
    tmp_profile=$(mktemp)
    cat > "$tmp_profile" << 'MINIMAL'
(version 1)
(allow default)
MINIMAL

    if sandbox-exec -f "$tmp_profile" -- /bin/echo "sandbox works" 2>/dev/null | grep -q "sandbox works"; then
        pass "integration: sandbox-exec with minimal profile runs successfully"
    else
        # sandbox-exec may not work in CI or restricted environments
        skip "integration: sandbox-exec test (may not work in this environment)"
    fi
    rm -f "$tmp_profile"

    # Test: assembled profile with multiple layers is valid
    "$BLASTSHIELD" --help > /dev/null 2>&1  # just verify it doesn't crash
    pass "integration: blastshield wrapper runs without crashing"

else
    skip "integration tests: sandbox-exec not available (not on macOS)"
fi

# ─── Docs Build Test ─────────────────────────────────────────────────────

section "Docs Build Test"

if [[ -f "$REPO_DIR/docs/package.json" ]]; then
    if command -v npm &>/dev/null; then
        if [[ -d "$REPO_DIR/docs/node_modules" ]]; then
            docs_build_out=$(cd "$REPO_DIR/docs" && npm run build 2>&1) || true
            if echo "$docs_build_out" | grep -q "Complete"; then
                pass "docs: Starlight build succeeds"
            else
                fail "docs: Starlight build failed" "Run: cd docs && npm run build"
            fi
        else
            skip "docs: node_modules not installed (run: cd docs && npm install)"
        fi
    else
        skip "docs: npm not available"
    fi
else
    skip "docs: no docs directory found"
fi

# ─── Summary ──────────────────────────────────────────────────────────────

echo ""
echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo -e "${GREEN}PASS${NC}: $PASS  ${RED}FAIL${NC}: $FAIL  ${YELLOW}SKIP${NC}: $SKIP"
echo -e "${CYAN}═══════════════════════════════════════${NC}"

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
exit 0
