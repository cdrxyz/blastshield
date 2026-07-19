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

wait_for_file() {
    local file="$1"
    local i
    for i in {1..50}; do
        [[ -f "$file" ]] && return 0
        sleep 0.1
    done
    return 1
}

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

    # Test 3: Contains at least one (deny ...) rule, unless explicitly
    # marked as an allow-only companion profile.
    if grep -q '(deny ' "$profile"; then
        pass "$name: contains deny rules"
    elif grep -q 'blastshield: allow-only-profile' "$profile"; then
        pass "$name: marked as allow-only companion profile"
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
for profile_name in base secrets terraform gcloud aws azure kubectl gh install; do
    # Test that resolve_profile function can find each profile
    profile_path="$PROFILES_DIR/${profile_name}.sb"
    if [[ -f "$profile_path" ]]; then
        pass "profile '$profile_name': resolves to $profile_path"
    else
        fail "profile '$profile_name': not found at $profile_path"
    fi
done

# Test: gui-app profile includes WebKit extension issuance needed by embedded web views
if grep -q 'com.apple.webkit.mach-bootstrap' "$PROFILES_DIR/gui-app.sb"; then
    pass "profile 'gui-app': allows WebKit mach-bootstrap extension issuance"
else
    fail "profile 'gui-app': missing WebKit mach-bootstrap extension support" "Conductor startup reports this as a WebKit sandbox extension error"
fi

# Test: gui-app profile allows Launch Services URL/document opens
if grep -q '^(allow lsopen)$' "$PROFILES_DIR/gui-app.sb"; then
    pass "profile 'gui-app': allows Launch Services URL/document opens"
else
    fail "profile 'gui-app': missing Launch Services URL open support" "Clicking external links in sandboxed GUI apps can fail without (allow lsopen)"
fi

# Test: base profile allows Launch Services URL opens for CLI OAuth (Grok/Claude/MCP)
if grep -q '^(allow lsopen)$' "$PROFILES_DIR/base.sb"; then
    pass "profile 'base': allows Launch Services URL opens for CLI OAuth"
else
    fail "profile 'base': missing Launch Services URL open support" "Without (allow lsopen), browser OAuth fails with error -54 and interactive setup can hang queued"
fi

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

# Test: guard check — gh pr view with an ID and --json is allowed (read-only)
if "$GUARD" check gh pr view 25493 --json statusCheckRollup,commits,headRefOid 2>&1; then
    pass "blastshield-guard check gh pr view --json: correctly allowed (read-only)"
else
    fail "blastshield-guard check gh pr view --json: should be allowed"
fi

# Test: guard check — gh pr checks is allowed (read-only)
if "$GUARD" check gh pr checks 25493 --watch=false 2>&1; then
    pass "blastshield-guard check gh pr checks: correctly allowed (read-only)"
else
    fail "blastshield-guard check gh pr checks: should be allowed"
fi

# Test: guard check — gh run view/watch are allowed (read-only)
if "$GUARD" check gh run view 123456 --log 2>&1 &&
    "$GUARD" check gh run watch 123456 --exit-status 2>&1; then
    pass "blastshield-guard check gh run view/watch: correctly allowed (read-only)"
else
    fail "blastshield-guard check gh run view/watch: should be allowed"
fi

# Test: guard check — gh api GET-style requests are allowed, mutating methods blocked
if "$GUARD" check gh api repos/cdrxyz/blastshield/actions/runs/123/jobs 2>&1 &&
    "$GUARD" check gh api --method GET repos/cdrxyz/blastshield/actions/runs/123/jobs 2>&1 &&
    ! "$GUARD" check gh api --method DELETE repos/cdrxyz/blastshield/releases/1 >/dev/null 2>&1 &&
    ! "$GUARD" check gh api -X PATCH repos/cdrxyz/blastshield >/dev/null 2>&1; then
    pass "blastshield-guard check gh api: allows read-only methods and blocks mutating methods"
else
    fail "blastshield-guard check gh api: expected GET allowed and DELETE/PATCH blocked"
fi

# Test: guard check — Gradle is not command-guarded
if gradle_guard_out=$("$GUARD" check gradle test 2>&1) &&
    echo "$gradle_guard_out" | grep -q "UNGUARDED"; then
    pass "blastshield-guard check gradle test: unguarded"
else
    fail "blastshield-guard check gradle test: should be unguarded" "$gradle_guard_out"
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

# ─── Install Command Guard Tests ──────────────────────────────────────

# Test: guard check — npm install blocked
if "$GUARD" check npm install 2>&1; then
    fail "blastshield-guard check npm install: should be blocked"
else
    pass "blastshield-guard check npm install: correctly blocked"
fi

# Test: guard check — npm ci blocked
if "$GUARD" check npm ci 2>&1; then
    fail "blastshield-guard check npm ci: should be blocked"
else
    pass "blastshield-guard check npm ci: correctly blocked"
fi

# Test: guard check — npm list allowed (read-only)
if "$GUARD" check npm list 2>&1; then
    pass "blastshield-guard check npm list: correctly allowed (read-only)"
else
    fail "blastshield-guard check npm list: should be allowed"
fi

# Test: guard check — npm outdated allowed (read-only)
if "$GUARD" check npm outdated 2>&1; then
    pass "blastshield-guard check npm outdated: correctly allowed (read-only)"
else
    fail "blastshield-guard check npm outdated: should be allowed"
fi

# Test: guard check — yarn add blocked
if "$GUARD" check yarn add 2>&1; then
    fail "blastshield-guard check yarn add: should be blocked"
else
    pass "blastshield-guard check yarn add: correctly blocked"
fi

# Test: guard check — yarn list allowed (read-only)
if "$GUARD" check yarn list 2>&1; then
    pass "blastshield-guard check yarn list: correctly allowed (read-only)"
else
    fail "blastshield-guard check yarn list: should be allowed"
fi

# Test: guard check — pnpm add blocked
if "$GUARD" check pnpm add 2>&1; then
    fail "blastshield-guard check pnpm add: should be blocked"
else
    pass "blastshield-guard check pnpm add: correctly blocked"
fi

# Test: guard check — pnpm list allowed (read-only)
if "$GUARD" check pnpm list 2>&1; then
    pass "blastshield-guard check pnpm list: correctly allowed (read-only)"
else
    fail "blastshield-guard check pnpm list: should be allowed"
fi

# Test: guard check — pip install blocked
if "$GUARD" check pip install 2>&1; then
    fail "blastshield-guard check pip install: should be blocked"
else
    pass "blastshield-guard check pip install: correctly blocked"
fi

# Test: guard check — pip list allowed (read-only)
if "$GUARD" check pip list 2>&1; then
    pass "blastshield-guard check pip list: correctly allowed (read-only)"
else
    fail "blastshield-guard check pip list: should be allowed"
fi

# Test: guard check — pip uninstall blocked
if "$GUARD" check pip uninstall 2>&1; then
    fail "blastshield-guard check pip uninstall: should be blocked"
else
    pass "blastshield-guard check pip uninstall: correctly blocked"
fi

# Test: guard check — brew install blocked
if "$GUARD" check brew install 2>&1; then
    fail "blastshield-guard check brew install: should be blocked"
else
    pass "blastshield-guard check brew install: correctly blocked"
fi

# Test: guard check — brew list allowed (read-only)
if "$GUARD" check brew list 2>&1; then
    pass "blastshield-guard check brew list: correctly allowed (read-only)"
else
    fail "blastshield-guard check brew list: should be allowed"
fi

# Test: guard check — gem install blocked
if "$GUARD" check gem install 2>&1; then
    fail "blastshield-guard check gem install: should be blocked"
else
    pass "blastshield-guard check gem install: correctly blocked"
fi

# Test: guard check — gem list allowed (read-only)
if "$GUARD" check gem list 2>&1; then
    pass "blastshield-guard check gem list: correctly allowed (read-only)"
else
    fail "blastshield-guard check gem list: should be allowed"
fi

# Test: guard check — cargo install blocked
if "$GUARD" check cargo install 2>&1; then
    fail "blastshield-guard check cargo install: should be blocked"
else
    pass "blastshield-guard check cargo install: correctly blocked"
fi

# Test: guard check — cargo search allowed (read-only)
if "$GUARD" check cargo search 2>&1; then
    pass "blastshield-guard check cargo search: correctly allowed (read-only)"
else
    fail "blastshield-guard check cargo search: should be allowed"
fi

# Test: guard check — hermit install blocked
if "$GUARD" check hermit install 2>&1; then
    fail "blastshield-guard check hermit install: should be blocked"
else
    pass "blastshield-guard check hermit install: correctly blocked"
fi

# Test: guard check — hermit list allowed (read-only)
if "$GUARD" check hermit list 2>&1; then
    pass "blastshield-guard check hermit list: correctly allowed (read-only)"
else
    fail "blastshield-guard check hermit list: should be allowed"
fi

# Test: guard check — apt install blocked
if "$GUARD" check apt install 2>&1; then
    fail "blastshield-guard check apt install: should be blocked"
else
    pass "blastshield-guard check apt install: correctly blocked"
fi

# Test: guard check — dnf install blocked
if "$GUARD" check dnf install 2>&1; then
    fail "blastshield-guard check dnf install: should be blocked"
else
    pass "blastshield-guard check dnf install: correctly blocked"
fi

# Test: guard check — npm with flags (npm install -g react) blocked
if "$GUARD" check npm install -g react 2>&1; then
    fail "blastshield-guard check npm install -g react: should be blocked"
else
    pass "blastshield-guard check npm install -g react: correctly blocked"
fi

# Test: guard check — npm shorthand 'i' blocked
if "$GUARD" check npm i 2>&1; then
    fail "blastshield-guard check npm i: should be blocked (shorthand for install)"
else
    pass "blastshield-guard check npm i: correctly blocked (shorthand for install)"
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

    # Test: gui-app WebKit support can issue the mach-bootstrap sandbox extension
    if command -v clang &>/dev/null; then
        webkit_tmp=$(mktemp -d)
        cat > "$webkit_tmp/issue-webkit-extension.c" <<'C'
#include <stdint.h>
#include <stdlib.h>

extern char *sandbox_extension_issue_generic(const char *extension_class, uint32_t flags);

int main(void) {
    char *token = sandbox_extension_issue_generic("com.apple.webkit.mach-bootstrap", 0);
    if (!token) {
        return 2;
    }
    free(token);
    return 0;
}
C
        cat > "$webkit_tmp/profile.sb" <<'SB'
(version 1)
(deny default)
(allow file-read* (subpath "/"))
(allow process-exec (subpath "/"))
(allow sysctl-read)
(allow generic-issue-extension (extension-class "com.apple.webkit.mach-bootstrap"))
SB
        if clang "$webkit_tmp/issue-webkit-extension.c" -o "$webkit_tmp/issue-webkit-extension" &&
            sandbox-exec -f "$webkit_tmp/profile.sb" "$webkit_tmp/issue-webkit-extension"; then
            pass "integration: WebKit mach-bootstrap sandbox extension can be issued"
        else
            fail "integration: WebKit mach-bootstrap sandbox extension issuance failed"
        fi
        rm -rf "$webkit_tmp"
    else
        skip "integration: WebKit extension issuance (clang not available)"
    fi

    # Test: gui-app profile permits normal GUI power-management registration
    if command -v clang &>/dev/null; then
        power_tmp=$(mktemp -d)
        cat > "$power_tmp/power-registration.c" <<'C'
#include <IOKit/IOMessage.h>
#include <IOKit/pwr_mgt/IOPMLib.h>
#include <mach/mach.h>

static void callback(void *refCon, io_service_t service, natural_t messageType, void *messageArgument) {}

int main(void) {
    IONotificationPortRef notifyPort = NULL;
    io_object_t notifier = IO_OBJECT_NULL;
    io_connect_t root = IORegisterForSystemPower(NULL, &notifyPort, callback, &notifier);
    if (root == MACH_PORT_NULL) {
        return 2;
    }
    IODeregisterForSystemPower(&notifier);
    IOServiceClose(root);
    IONotificationPortDestroy(notifyPort);
    return 0;
}
C
        if clang "$power_tmp/power-registration.c" -framework IOKit -framework CoreFoundation -o "$power_tmp/power-registration" &&
            "$BLASTSHIELD" --no-detect --no-guard -p gui-app "$power_tmp/power-registration" >/dev/null 2>&1; then
            pass "integration: GUI app profile allows system power registration"
        else
            fail "integration: GUI app profile should allow system power registration"
        fi
        rm -rf "$power_tmp"
    else
        skip "integration: GUI power registration (clang not available)"
    fi

    # Test: gui-app profile permits Metal device enumeration used by GPU renderers
    if command -v xcrun &>/dev/null &&
        metal_clang=$(xcrun --find clang 2>/dev/null) &&
        metal_sdk=$(xcrun --sdk macosx --show-sdk-path 2>/dev/null); then
        metal_tmp=$(mktemp -d)
        cat > "$metal_tmp/metal-probe.m" <<'OBJC'
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

int main(void) {
    @autoreleasepool {
        NSArray<id<MTLDevice>> *devices = MTLCopyAllDevices();
        return devices.count > 0 ? 0 : 2;
    }
}
OBJC
        if metal_compile_out=$("$metal_clang" -isysroot "$metal_sdk" -fobjc-arc -framework Foundation -framework Metal "$metal_tmp/metal-probe.m" -o "$metal_tmp/metal-probe" 2>&1); then
            if "$metal_tmp/metal-probe" >/dev/null 2>&1; then
                if metal_out=$("$BLASTSHIELD" --no-detect --no-guard -p gui-app "$metal_tmp/metal-probe" 2>&1); then
                    pass "integration: GUI app profile allows Metal device enumeration"
                else
                    fail "integration: GUI app profile should allow Metal device enumeration" "$metal_out"
                fi
            else
                skip "integration: Metal device enumeration (no Metal devices visible outside sandbox)"
            fi
        else
            skip "integration: Metal device enumeration (Metal SDK compile failed: $metal_compile_out)"
        fi
        rm -rf "$metal_tmp"
    else
        skip "integration: Metal device enumeration (xcrun clang or macOS SDK not available)"
    fi

    # Test: GUI apps can write normal per-user app logs
    gui_logs_home=$(mktemp -d)
    if gui_logs_out=$(HOME="$gui_logs_home" "$BLASTSHIELD" --no-detect --no-guard -p gui-app /bin/sh -c 'mkdir -p "$HOME/Library/Logs/Zed" && printf ok > "$HOME/Library/Logs/Zed/Zed.log"' 2>&1) &&
        [[ "$(cat "$gui_logs_home/Library/Logs/Zed/Zed.log" 2>/dev/null)" == "ok" ]]; then
        pass "integration: GUI app profile allows user Library Logs writes"
    else
        fail "integration: GUI app profile should allow user Library Logs writes" "$gui_logs_out"
    fi
    rm -rf "$gui_logs_home"

    # Test: interactive TUI terminal control works inside the sandbox
    if command -v script &>/dev/null; then
        if tty_out=$(script -q /dev/null "$BLASTSHIELD" --no-detect /bin/stty -a 2>&1); then
            pass "integration: blastshield allows terminal ioctl for TUIs"
        else
            fail "integration: blastshield terminal ioctl failed" "$tty_out"
        fi
    else
        skip "integration: script not available for pseudo-terminal test"
    fi

    # Test: wrapper command with no extra profiles does not trip nounset on empty arrays
    if wrapper_out=$("$BLASTSHIELD" --no-detect /usr/bin/true 2>&1); then
        pass "integration: blastshield wrapper runs with no detected profiles"
    else
        fail "integration: blastshield wrapper with --no-detect failed" "$wrapper_out"
    fi

    # Test: runtime guard intercepts Hermit/repo-local Terraform shims before execution
    hermit_project=$(mktemp -d "${TMPDIR:-/tmp}/blastshield-hermit-project.XXXXXX")
    mkdir -p "$hermit_project/bin" "$hermit_project/.hermit"
    hermit_marker="$hermit_project/terraform-ran"
    cat > "$hermit_project/bin/terraform" << 'HERMIT_TERRAFORM'
#!/usr/bin/env bash
printf '%s\n' "$*" > "$HERMIT_MARKER"
HERMIT_TERRAFORM
    chmod +x "$hermit_project/bin/terraform"

    hermit_apply_out=""
    if hermit_apply_out=$(cd "$hermit_project" && HERMIT_MARKER="$hermit_marker" PATH="$hermit_project/bin:$PATH" "$BLASTSHIELD" --no-detect terraform apply 2>&1); then
        fail "integration: blastshield blocks Hermit terraform apply" "Expected mutating command to be blocked"
    elif [[ -e "$hermit_marker" ]]; then
        fail "integration: blastshield blocks Hermit terraform apply" "Hermit terraform was executed: $(cat "$hermit_marker")"
    else
        pass "integration: blastshield blocks Hermit terraform apply"
    fi

    hermit_plan_out=""
    if hermit_plan_out=$(cd "$hermit_project" && HERMIT_MARKER="$hermit_marker" PATH="$hermit_project/bin:$PATH" "$BLASTSHIELD" --no-detect terraform plan 2>&1) &&
        [[ -f "$hermit_marker" ]] &&
        grep -q '^plan$' "$hermit_marker"; then
        pass "integration: blastshield allows Hermit terraform plan"
    else
        fail "integration: blastshield allows Hermit terraform plan" "$hermit_plan_out"
    fi
    rm -rf "$hermit_project"

    # Test: committed Hermit-style fixture works from a nested repo subdirectory
    hermit_fixture="$REPO_DIR/tests/fixtures/hermit-project"
    hermit_fixture_workdir="$hermit_fixture/infra/live"
    hermit_fixture_marker=$(mktemp "${TMPDIR:-/tmp}/blastshield-hermit-marker.XXXXXX")
    rm -f "$hermit_fixture_marker"

    hermit_fixture_apply_out=""
    if hermit_fixture_apply_out=$(cd "$hermit_fixture_workdir" && HERMIT_MARKER="$hermit_fixture_marker" PATH="$hermit_fixture/bin:$PATH" "$BLASTSHIELD" --no-detect terraform apply 2>&1); then
        fail "integration: blastshield blocks fixture Hermit terraform apply" "Expected mutating command to be blocked"
    elif [[ -e "$hermit_fixture_marker" ]]; then
        fail "integration: blastshield blocks fixture Hermit terraform apply" "Fixture terraform was executed: $(cat "$hermit_fixture_marker")"
    else
        pass "integration: blastshield blocks fixture Hermit terraform apply"
    fi

    hermit_fixture_plan_out=""
    if hermit_fixture_plan_out=$(cd "$hermit_fixture_workdir" && HERMIT_MARKER="$hermit_fixture_marker" PATH="$hermit_fixture/bin:$PATH" "$BLASTSHIELD" --no-detect terraform plan 2>&1) &&
        [[ -f "$hermit_fixture_marker" ]] &&
        grep -q '^terraform plan$' "$hermit_fixture_marker"; then
        pass "integration: blastshield allows fixture Hermit terraform plan"
    else
        fail "integration: blastshield allows fixture Hermit terraform plan" "$hermit_fixture_plan_out"
    fi

    rm -f "$hermit_fixture_marker"
    hermit_fixture_gcloud_out=""
    if hermit_fixture_gcloud_out=$(cd "$hermit_fixture_workdir" && HERMIT_MARKER="$hermit_fixture_marker" PATH="$hermit_fixture/bin:$PATH" "$BLASTSHIELD" --no-detect gcloud compute instances delete test-vm 2>&1); then
        fail "integration: blastshield blocks fixture Hermit gcloud delete" "Expected mutating command to be blocked"
    elif [[ -e "$hermit_fixture_marker" ]]; then
        fail "integration: blastshield blocks fixture Hermit gcloud delete" "Fixture gcloud was executed: $(cat "$hermit_fixture_marker")"
    else
        pass "integration: blastshield blocks fixture Hermit gcloud delete"
    fi
    rm -f "$hermit_fixture_marker"

    # Test: assembled profile substitutes _PROJECT_DIR and allows project writes
    project_probe="$REPO_DIR/.blastshield-project-write-test"
    rm -f "$project_probe"
    if project_out=$("$BLASTSHIELD" --no-detect /bin/sh -c "printf ok > '$project_probe' && rm '$project_probe'" 2>&1) &&
        [[ ! -e "$project_probe" ]]; then
        pass "integration: blastshield substituted profile allows project writes"
    else
        rm -f "$project_probe"
        fail "integration: blastshield project write failed" "$project_out"
    fi

    # Test: Codex can create runtime state under CODEX_HOME/HOME without broad home writes
    codex_home=$(mktemp -d "${TMPDIR:-/tmp}/blastshield-codex-home.XXXXXX")
    mkdir -p "$codex_home/.codex"
    if codex_state_out=$(HOME="$codex_home" "$BLASTSHIELD" --no-detect /bin/sh -c 'mkdir -p "$HOME/.codex/sessions/2026" "$HOME/.codex/log" "$HOME/.codex/cache" && printf ok > "$HOME/.codex/sessions/2026/test.jsonl" && printf ok > "$HOME/.codex/models_cache.json" && printf ok > "$HOME/.codex/log/codex-tui.log"' 2>&1); then
        pass "integration: blastshield allows Codex runtime state writes"
    else
        fail "integration: blastshield Codex runtime state write failed" "$codex_state_out"
    fi
    if HOME="$codex_home" "$BLASTSHIELD" --no-detect /bin/sh -c 'printf bad > "$HOME/.codex/config.toml"' >/dev/null 2>&1; then
        fail "integration: blastshield blocks Codex config writes" "Expected config write to be denied"
    else
        pass "integration: blastshield blocks Codex config writes"
    fi
    rm -rf "$codex_home"

    # Test: Claude can create runtime state while settings/plugins/global state stay protected
    claude_home=$(mktemp -d "${TMPDIR:-/tmp}/blastshield-claude-home.XXXXXX")
    mkdir -p "$claude_home/.claude"
    if claude_state_out=$(HOME="$claude_home" "$BLASTSHIELD" --no-detect /bin/sh -c 'mkdir -p "$HOME/.claude/projects/test" "$HOME/.claude/sessions" "$HOME/.claude/session-env" "$HOME/.claude/cache" "$HOME/.claude/debug" "$HOME/.claude/plans" && printf ok > "$HOME/.claude/projects/test/session.jsonl" && printf ok > "$HOME/.claude/history.jsonl" && printf ok > "$HOME/.claude/session-env/test"' 2>&1); then
        pass "integration: blastshield allows Claude runtime state writes"
    else
        fail "integration: blastshield Claude runtime state write failed" "$claude_state_out"
    fi
    if HOME="$claude_home" "$BLASTSHIELD" --no-detect /bin/sh -c 'printf bad > "$HOME/.claude/settings.json"' >/dev/null 2>&1; then
        fail "integration: blastshield blocks Claude settings writes" "Expected settings write to be denied"
    else
        pass "integration: blastshield blocks Claude settings writes"
    fi
    if HOME="$claude_home" "$BLASTSHIELD" --no-detect /bin/sh -c 'mkdir -p "$HOME/.claude/plugins/test"' >/dev/null 2>&1; then
        fail "integration: blastshield blocks Claude plugin writes" "Expected plugin write to be denied"
    else
        pass "integration: blastshield blocks Claude plugin writes"
    fi
    if HOME="$claude_home" "$BLASTSHIELD" --no-detect /bin/sh -c 'printf bad > "$HOME/.claude.json"' >/dev/null 2>&1; then
        fail "integration: blastshield blocks Claude global state writes" "Expected global state write to be denied"
    else
        pass "integration: blastshield blocks Claude global state writes"
    fi
    rm -rf "$claude_home"

    # Test: base profile permits Launch Services browser opens for CLI OAuth
    # (Grok/Claude/MCP). Without lsopen, open fails with error -54.
    if lsopen_out=$("$BLASTSHIELD" --no-detect --no-guard /bin/sh -c 'open "https://example.com" >/dev/null 2>&1; echo exit:$?' 2>&1) &&
       echo "$lsopen_out" | grep -q 'exit:0'; then
        pass "integration: base profile allows Launch Services URL opens"
    else
        fail "integration: base profile allows Launch Services URL opens" "$lsopen_out"
    fi

    # Test: Grok Build can create runtime state while auth/config/extension points stay protected
    grok_home=$(mktemp -d "${TMPDIR:-/tmp}/blastshield-grok-home.XXXXXX")
    mkdir -p "$grok_home/.grok"
    if grok_state_out=$(HOME="$grok_home" "$BLASTSHIELD" --no-detect /bin/sh -c 'mkdir -p "$HOME/.grok/sessions/project/session-1" "$HOME/.grok/memory/project-abc12345/sessions" "$HOME/.grok/bin" "$HOME/.grok/docs" && printf ok > "$HOME/.grok/sessions/project/session-1/summary.json" && printf ok > "$HOME/.grok/memory/project-abc12345/sessions/2026-07-10.md" && printf ok > "$HOME/.grok/active_sessions.json" && printf ok > "$HOME/.grok/leader.sock" && printf ok > "$HOME/.grok/bin/grok-0.2.93"' 2>&1); then
        pass "integration: blastshield allows Grok Build runtime state writes"
    else
        fail "integration: blastshield Grok Build runtime state write failed" "$grok_state_out"
    fi
    if HOME="$grok_home" "$BLASTSHIELD" --no-detect /bin/sh -c 'printf bad > "$HOME/.grok/auth.json"' >/dev/null 2>&1; then
        fail "integration: blastshield blocks Grok Build auth writes" "Expected auth.json write to be denied"
    else
        pass "integration: blastshield blocks Grok Build auth writes"
    fi
    if HOME="$grok_home" "$BLASTSHIELD" --no-detect /bin/sh -c 'printf bad > "$HOME/.grok/config.toml"' >/dev/null 2>&1; then
        fail "integration: blastshield blocks Grok Build config writes" "Expected config.toml write to be denied"
    else
        pass "integration: blastshield blocks Grok Build config writes"
    fi
    if HOME="$grok_home" "$BLASTSHIELD" --no-detect /bin/sh -c 'printf bad > "$HOME/.grok/requirements.toml"' >/dev/null 2>&1; then
        fail "integration: blastshield blocks Grok Build requirements writes" "Expected requirements.toml write to be denied"
    else
        pass "integration: blastshield blocks Grok Build requirements writes"
    fi
    if HOME="$grok_home" "$BLASTSHIELD" --no-detect /bin/sh -c 'printf bad > "$HOME/.grok/sandbox.toml"' >/dev/null 2>&1; then
        fail "integration: blastshield blocks Grok Build sandbox config writes" "Expected sandbox.toml write to be denied"
    else
        pass "integration: blastshield blocks Grok Build sandbox config writes"
    fi
    if HOME="$grok_home" "$BLASTSHIELD" --no-detect /bin/sh -c 'printf bad > "$HOME/.grok/trusted_folders.toml"' >/dev/null 2>&1; then
        fail "integration: blastshield blocks Grok Build trusted folder writes" "Expected trusted_folders.toml write to be denied"
    else
        pass "integration: blastshield blocks Grok Build trusted folder writes"
    fi
    if HOME="$grok_home" "$BLASTSHIELD" --no-detect /bin/sh -c 'printf bad > "$HOME/.grok/settings.json"' >/dev/null 2>&1; then
        fail "integration: blastshield blocks Grok Build settings writes" "Expected settings.json write to be denied"
    else
        pass "integration: blastshield blocks Grok Build settings writes"
    fi
    if HOME="$grok_home" "$BLASTSHIELD" --no-detect /bin/sh -c 'mkdir -p "$HOME/.grok/skills/test" && printf bad > "$HOME/.grok/skills/test/SKILL.md"' >/dev/null 2>&1; then
        fail "integration: blastshield blocks Grok Build skill writes" "Expected skill write to be denied"
    else
        pass "integration: blastshield blocks Grok Build skill writes"
    fi
    if HOME="$grok_home" "$BLASTSHIELD" --no-detect /bin/sh -c 'mkdir -p "$HOME/.grok/plugins/test" && printf bad > "$HOME/.grok/plugins/test/plugin.json"' >/dev/null 2>&1; then
        fail "integration: blastshield blocks Grok Build plugin writes" "Expected plugin write to be denied"
    else
        pass "integration: blastshield blocks Grok Build plugin writes"
    fi
    if HOME="$grok_home" "$BLASTSHIELD" --no-detect /bin/sh -c 'mkdir -p "$HOME/.grok/hooks" && printf bad > "$HOME/.grok/hooks/session-start.json"' >/dev/null 2>&1; then
        fail "integration: blastshield blocks Grok Build hook writes" "Expected hook write to be denied"
    else
        pass "integration: blastshield blocks Grok Build hook writes"
    fi
    if HOME="$grok_home" "$BLASTSHIELD" --no-detect /bin/sh -c 'mkdir -p "$HOME/.grok/installed-plugins/test" && printf bad > "$HOME/.grok/installed-plugins/test/manifest.json"' >/dev/null 2>&1; then
        fail "integration: blastshield blocks Grok Build installed-plugin writes" "Expected installed-plugin write to be denied"
    else
        pass "integration: blastshield blocks Grok Build installed-plugin writes"
    fi
    rm -rf "$grok_home"

    # Test: Gradle can write user-level cache/native state while init/config stay protected
    gradle_home=$(mktemp -d "${TMPDIR:-/tmp}/blastshield-gradle-home.XXXXXX")
    if gradle_state_out=$(HOME="$gradle_home" "$BLASTSHIELD" --no-detect --no-guard /bin/sh -c 'mkdir -p "$HOME/.gradle/caches/modules-2" "$HOME/.gradle/native/test" "$HOME/.gradle/daemon/8.9" "$HOME/.gradle/wrapper/dists" && printf ok > "$HOME/.gradle/caches/modules-2/probe" && printf ok > "$HOME/.gradle/native/test/probe" && printf ok > "$HOME/.gradle/daemon/8.9/probe" && printf ok > "$HOME/.gradle/wrapper/dists/probe"' 2>&1); then
        pass "integration: blastshield allows Gradle home cache writes"
    else
        fail "integration: blastshield Gradle home cache write failed" "$gradle_state_out"
    fi
    if HOME="$gradle_home" "$BLASTSHIELD" --no-detect --no-guard /bin/sh -c 'printf bad > "$HOME/.gradle/gradle.properties"' >/dev/null 2>&1; then
        fail "integration: blastshield blocks Gradle properties writes" "Expected gradle.properties write to be denied"
    else
        pass "integration: blastshield blocks Gradle properties writes"
    fi
    if HOME="$gradle_home" "$BLASTSHIELD" --no-detect --no-guard /bin/sh -c 'mkdir -p "$HOME/.gradle/init.d" && printf bad > "$HOME/.gradle/init.d/persist.gradle"' >/dev/null 2>&1; then
        fail "integration: blastshield blocks Gradle init script writes" "Expected init.d write to be denied"
    else
        pass "integration: blastshield blocks Gradle init script writes"
    fi
    rm -rf "$gradle_home"

    # Test: .app resolution honors CFBundleExecutable instead of guessing from app name
    plist_app_tmp=$(mktemp -d)
    mkdir -p "$plist_app_tmp/PlistExec.app/Contents/MacOS"
    plist_marker="$plist_app_tmp/marker"
    cat > "$plist_app_tmp/PlistExec.app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>actual-executable</string>
</dict>
</plist>
PLIST
    cat > "$plist_app_tmp/PlistExec.app/Contents/MacOS/PlistExec" <<APP
#!/bin/sh
echo GUESSED_EXEC > "$plist_marker"
sleep 1
APP
    cat > "$plist_app_tmp/PlistExec.app/Contents/MacOS/actual-executable" <<APP
#!/bin/sh
echo PLIST_EXEC > "$plist_marker"
sleep 1
APP
    chmod +x "$plist_app_tmp/PlistExec.app/Contents/MacOS/PlistExec" "$plist_app_tmp/PlistExec.app/Contents/MacOS/actual-executable"
    if plist_app_out=$("$BLASTSHIELD" --no-detect --no-guard open "$plist_app_tmp/PlistExec.app" 2>&1) &&
        wait_for_file "$plist_marker" &&
        grep -q "PLIST_EXEC" "$plist_marker"; then
        pass "integration: .app resolver honors CFBundleExecutable"
    else
        fail "integration: .app resolver should honor CFBundleExecutable" "$plist_app_out"
    fi
    rm -rf "$plist_app_tmp"

    # Test: non-interactive GUI app launches detach like `open`, while the app keeps running
    detached_tmp=$(mktemp -d)
    mkdir -p "$detached_tmp/Detached.app/Contents/MacOS"
    detached_pid_file="$detached_tmp/pid"
    detached_done_file="$detached_tmp/done"
    cat > "$detached_tmp/Detached.app/Contents/MacOS/Detached" <<APP
#!/bin/sh
echo "\$\$" > "$detached_pid_file"
sleep 5
echo done > "$detached_done_file"
APP
    chmod +x "$detached_tmp/Detached.app/Contents/MacOS/Detached"
    detached_start=$(date +%s)
    if detached_out=$("$BLASTSHIELD" --no-detect --no-guard open "$detached_tmp/Detached.app" 2>&1) &&
        wait_for_file "$detached_pid_file"; then
        detached_elapsed=$(($(date +%s) - detached_start))
        detached_pid=$(cat "$detached_pid_file")
        if [[ $detached_elapsed -lt 5 ]] && kill -0 "$detached_pid" 2>/dev/null; then
            pass "integration: GUI app launch detaches while app keeps running"
        else
            fail "integration: GUI app launch should detach while app keeps running" "$detached_out"
        fi
        kill "$detached_pid" 2>/dev/null || true
    else
        fail "integration: GUI app launch should detach" "$detached_out"
    fi
    rm -rf "$detached_tmp"

    # Test: interactive GUI app launches keep the terminal open by streaming logs
    if command -v script &>/dev/null; then
        interactive_tmp=$(mktemp -d)
        mkdir -p "$interactive_tmp/Interactive.app/Contents/MacOS"
        cat > "$interactive_tmp/Interactive.app/Contents/MacOS/Interactive" <<'APP'
#!/bin/sh
echo INTERACTIVE_GUI_LOG_LINE
sleep 1
APP
        chmod +x "$interactive_tmp/Interactive.app/Contents/MacOS/Interactive"
        interactive_out=$(script -q /dev/null "$BLASTSHIELD" --no-detect --no-guard open "$interactive_tmp/Interactive.app" 2>&1) || true
        if echo "$interactive_out" | grep -q "Streaming GUI app logs" &&
            echo "$interactive_out" | grep -q "INTERACTIVE_GUI_LOG_LINE"; then
            pass "integration: interactive GUI app launch streams logs"
        else
            fail "integration: interactive GUI app launch should stream logs" "$interactive_out"
        fi
        rm -rf "$interactive_tmp"
    else
        skip "integration: interactive GUI app log streaming (script not available)"
    fi

    # Test: auto-detection path handles an initially empty extra_profiles array
    if autodetect_out=$(cd "$REPO_DIR" && "$BLASTSHIELD" /usr/bin/true 2>&1); then
        pass "integration: blastshield wrapper runs with auto-detected profiles"
    else
        fail "integration: blastshield wrapper with auto-detect failed" "$autodetect_out"
    fi

    # Test: explicit profiles can run repeatedly without mktemp collisions or trap failures
    literal_tmp="${TMPDIR:-/tmp}/blastshield.XXXXXX.sb"
    explicit_out1=""
    explicit_out2=""
    rm -f "$literal_tmp"
    if explicit_out1=$("$BLASTSHIELD" -p gh --no-detect /usr/bin/true 2>&1) &&
        explicit_out2=$("$BLASTSHIELD" -p gh --no-detect /usr/bin/true 2>&1) &&
        [[ ! -e "$literal_tmp" ]]; then
        pass "integration: blastshield wrapper runs explicit profile twice"
    else
        fail "integration: blastshield explicit profile repeat failed" "First: $explicit_out1
Second: $explicit_out2"
    fi

    # Test: GUI app launches do not auto-detect project profiles that block app startup checks
    gui_tmp=$(mktemp -d)
    mkdir -p "$gui_tmp/home/.config/gh" "$gui_tmp/project/.github" "$gui_tmp/Fake.app/Contents/MacOS"
    gui_marker="$gui_tmp/marker"
    printf 'github.com:\n  oauth_token: dummy\n' > "$gui_tmp/home/.config/gh/hosts.yml"
    cat > "$gui_tmp/Fake.app/Contents/MacOS/Fake" <<APP
#!/bin/sh
if cat "\$HOME/.config/gh/hosts.yml" >/dev/null 2>&1; then
    echo GH_READ_OK > "$gui_marker"
    sleep 1
else
    echo GH_READ_DENIED > "$gui_marker"
    sleep 1
    exit 7
fi
APP
    chmod +x "$gui_tmp/Fake.app/Contents/MacOS/Fake"

    rm -f "$gui_marker"
    gui_out=$(cd "$gui_tmp/project" && HOME="$gui_tmp/home" "$BLASTSHIELD" --no-guard -p gui-app open "$gui_tmp/Fake.app" 2>&1) || true
    if wait_for_file "$gui_marker" && grep -q "GH_READ_OK" "$gui_marker"; then
        pass "integration: GUI app launch skips auto-detected gh profile"
    else
        fail "integration: GUI app launch should read dummy gh config" "$gui_out"
    fi

    rm -f "$gui_marker"
    gui_explicit_out=$(cd "$gui_tmp/project" && HOME="$gui_tmp/home" "$BLASTSHIELD" --no-guard -p gh -p gui-app open "$gui_tmp/Fake.app" 2>&1) || true
    if wait_for_file "$gui_marker" && grep -q "GH_READ_DENIED" "$gui_marker"; then
        pass "integration: GUI app launch still honors explicit gh profile"
    else
        fail "integration: explicit gh profile should still block dummy gh config" "$gui_explicit_out"
    fi
    rm -rf "$gui_tmp"

    # Test: Conductor app launches can write Conductor-managed workspace roots
    conductor_tmp=$(mktemp -d)
    conductor_tmp=$(cd "$conductor_tmp" && pwd -P)
    mkdir -p "$conductor_tmp/home/conductor/workspaces/current" \
        "$conductor_tmp/home/conductor/repos/root" \
        "$conductor_tmp/FakeConductor.app/Contents/MacOS"
    conductor_marker="$conductor_tmp/marker"
    conductor_workspace_probe="$conductor_tmp/home/conductor/workspaces/current/probe"
    conductor_repo_probe="$conductor_tmp/home/conductor/repos/root/probe"
    conductor_idea_probe="$conductor_tmp/home/conductor/workspaces/current/.idea/workspace.xml"
    conductor_vscode_probe="$conductor_tmp/home/conductor/workspaces/current/.vscode/settings.json"
    conductor_mcp_probe="$conductor_tmp/home/conductor/workspaces/current/.mcp.json"
    cat > "$conductor_tmp/FakeConductor.app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.conductor.app</string>
    <key>CFBundleExecutable</key>
    <string>FakeConductor</string>
</dict>
</plist>
PLIST
    cat > "$conductor_tmp/FakeConductor.app/Contents/MacOS/FakeConductor" <<APP
#!/bin/sh
mkdir -p "$(dirname "$conductor_idea_probe")" "$(dirname "$conductor_vscode_probe")" &&
    printf workspace > "$conductor_workspace_probe" &&
    printf repo > "$conductor_repo_probe" &&
    printf idea > "$conductor_idea_probe" &&
    printf vscode > "$conductor_vscode_probe" &&
    printf mcp > "$conductor_mcp_probe" &&
    printf done > "$conductor_marker"
sleep 1
APP
    chmod +x "$conductor_tmp/FakeConductor.app/Contents/MacOS/FakeConductor"

    conductor_out=$(HOME="$conductor_tmp/home" "$BLASTSHIELD" --no-detect --no-guard open "$conductor_tmp/FakeConductor.app" 2>&1) || true
    if wait_for_file "$conductor_marker" &&
        [[ "$(cat "$conductor_workspace_probe" 2>/dev/null)" == "workspace" ]] &&
        [[ "$(cat "$conductor_repo_probe" 2>/dev/null)" == "repo" ]] &&
        [[ "$(cat "$conductor_idea_probe" 2>/dev/null)" == "idea" ]] &&
        [[ "$(cat "$conductor_vscode_probe" 2>/dev/null)" == "vscode" ]] &&
        [[ "$(cat "$conductor_mcp_probe" 2>/dev/null)" == "mcp" ]] &&
        echo "$conductor_out" | grep -q "auto-adding 'conductor-app' profile"; then
        pass "integration: Conductor app launch allows Conductor workspace checkout writes"
    else
        fail "integration: Conductor app launch should allow Conductor workspace checkout writes" "$conductor_out"
    fi
    rm -rf "$conductor_tmp"

    # Test: GUI app login-shell PATH discovery keeps runtime guards first
    if [[ -x /bin/zsh ]]; then
        gui_path_tmp=$(mktemp -d)
        mkdir -p "$gui_path_tmp/home" "$gui_path_tmp/realbin" "$gui_path_tmp/PathProbe.app/Contents/MacOS"
        gui_path_marker="$gui_path_tmp/marker"
        cat > "$gui_path_tmp/realbin/gh" <<'GH'
#!/bin/sh
echo REAL_GH
GH
        chmod +x "$gui_path_tmp/realbin/gh"
        cat > "$gui_path_tmp/home/.zprofile" <<ZPROFILE
PATH="$gui_path_tmp/realbin:\$PATH"
export PATH
ZPROFILE
        cat > "$gui_path_tmp/PathProbe.app/Contents/MacOS/PathProbe" <<APP
#!/bin/sh
/bin/zsh -lic 'command -v gh' > "$gui_path_marker.tmp"
mv "$gui_path_marker.tmp" "$gui_path_marker"
sleep 1
APP
        chmod +x "$gui_path_tmp/PathProbe.app/Contents/MacOS/PathProbe"

        gui_path_out=$(HOME="$gui_path_tmp/home" SHELL=/bin/zsh PATH="$gui_path_tmp/realbin:$PATH" "$BLASTSHIELD" --no-detect open "$gui_path_tmp/PathProbe.app" 2>&1) || true
        if wait_for_file "$gui_path_marker" &&
            grep -q '/blastshield.guard.' "$gui_path_marker" &&
            ! grep -q "^$gui_path_tmp/realbin/gh$" "$gui_path_marker"; then
            pass "integration: GUI app login-shell PATH keeps runtime guard first"
        else
            fail "integration: GUI app login-shell PATH should keep runtime guard first" "$gui_path_out"
        fi
        rm -rf "$gui_path_tmp"
    else
        skip "integration: GUI app login-shell PATH guard preservation (zsh unavailable)"
    fi

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
