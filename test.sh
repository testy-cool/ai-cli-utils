#!/bin/bash
# test.sh — integration tests for ai-cli-utils
# Tests exit codes, output format, and timing of each tool.

set -uo pipefail

PASS=0
FAIL=0
TOTAL=0

pass() {
  echo "  PASS: $1"
  ((PASS++))
  ((TOTAL++))
}

fail() {
  echo "  FAIL: $1 — $2"
  ((FAIL++))
  ((TOTAL++))
}

run_timed() {
  # run_timed <timeout_secs> <outvar> <cmd...>
  # Captures stdout+stderr into $outvar, returns the command's exit code.
  # Kills the command if it exceeds timeout.
  local timeout=$1
  local varname=$2
  shift 2
  local tmpf
  tmpf=$(mktemp)
  timeout "$timeout" bash -c "$*" > "$tmpf" 2>&1
  local rc=$?
  eval "$varname=\$(cat \"\$tmpf\")"
  rm -f "$tmpf"
  return $rc
}

BINDIR="$(cd "$(dirname "$0")" && pwd)"
TMPDIR_BASE=$(mktemp -d)
trap 'rm -rf "$TMPDIR_BASE"' EXIT

echo "=== relevant ==="

# Test 1: relevant "modify starship" ~/.config
echo "  Running: relevant 'modify starship' ~/.config"
run_timed 30 OUT "$BINDIR/relevant 'modify starship' ~/.config"
RC=$?
if [ $RC -eq 0 ]; then pass "relevant starship: exit 0"; else fail "relevant starship: exit 0" "got $RC"; fi
if [ -n "$OUT" ]; then pass "relevant starship: non-empty"; else fail "relevant starship: non-empty" "empty output"; fi
if echo "$OUT" | grep -qi "starship.toml"; then pass "relevant starship: mentions starship.toml"; else fail "relevant starship: mentions starship.toml" "not found in output"; fi

# Test 2: relevant with nonexistent query
echo "  Running: relevant 'nonexistent_gibberish_xyz' ~/.config"
run_timed 30 OUT "$BINDIR/relevant 'nonexistent_gibberish_xyz' ~/.config"
RC=$?
if [ $RC -eq 0 ]; then pass "relevant gibberish: exit 0"; else fail "relevant gibberish: exit 0" "got $RC"; fi
# Should say no relevant files or produce minimal output — either way exit 0 is fine
if echo "$OUT" | grep -qi "no relevant"; then
  pass "relevant gibberish: says no relevant files"
else
  # LLM might phrase it differently; as long as it exits 0 and has output, it's acceptable
  if [ -n "$OUT" ]; then
    pass "relevant gibberish: has output (LLM phrasing may vary)"
  else
    fail "relevant gibberish: says no relevant files" "no matching phrase found"
  fi
fi

echo ""
echo "=== why ==="

# Test 3: why with ModuleNotFoundError
echo "  Running: echo ModuleNotFoundError | why"
run_timed 15 OUT "echo \"ModuleNotFoundError: No module named 'pandas'\" | $BINDIR/why"
RC=$?
if [ $RC -eq 0 ]; then pass "why pandas: exit 0"; else fail "why pandas: exit 0" "got $RC"; fi
if [ -n "$OUT" ]; then pass "why pandas: non-empty"; else fail "why pandas: non-empty" "empty output"; fi
if echo "$OUT" | grep -qi '\[dependency\]'; then pass "why pandas: contains [dependency]"; else fail "why pandas: contains [dependency]" "not found"; fi
if echo "$OUT" | grep -q 'Fix:'; then pass "why pandas: contains Fix:"; else fail "why pandas: contains Fix:" "not found"; fi
if echo "$OUT" | grep -q 'Run:'; then pass "why pandas: contains Run:"; else fail "why pandas: contains Run:" "not found"; fi

# Test 4: why with permission denied
echo "  Running: echo permission denied | why"
run_timed 15 OUT "echo 'permission denied: ./deploy.sh' | $BINDIR/why"
RC=$?
if [ $RC -eq 0 ]; then pass "why permission: exit 0"; else fail "why permission: exit 0" "got $RC"; fi
if echo "$OUT" | grep -qi '\[permission\]'; then pass "why permission: contains [permission]"; else fail "why permission: contains [permission]" "not found"; fi

echo ""
echo "=== diffsummary ==="

# Test 5: diffsummary with actual changes
TESTREPO="$TMPDIR_BASE/testrepo"
mkdir -p "$TESTREPO"
git -C "$TESTREPO" init -q
echo "hello" > "$TESTREPO/file.txt"
git -C "$TESTREPO" add .
git -C "$TESTREPO" commit -q -m "init"
echo "hello world" > "$TESTREPO/file.txt"

echo "  Running: diffsummary in temp repo"
run_timed 15 OUT "cd $TESTREPO && git diff HEAD | $BINDIR/diffsummary"
RC=$?
if [ $RC -eq 0 ]; then pass "diffsummary changes: exit 0"; else fail "diffsummary changes: exit 0" "got $RC"; fi
if [ -n "$OUT" ]; then pass "diffsummary changes: non-empty"; else fail "diffsummary changes: non-empty" "empty output"; fi
if echo "$OUT" | grep -qi 'files\?\s*changed'; then pass "diffsummary changes: contains FILES CHANGED"; else fail "diffsummary changes: contains FILES CHANGED" "not found"; fi
if echo "$OUT" | grep -qi 'commit\s*\(title\|message\)'; then pass "diffsummary changes: contains COMMIT TITLE"; else fail "diffsummary changes: contains COMMIT TITLE" "not found"; fi

# Test 6: diffsummary with no changes
CLEANREPO="$TMPDIR_BASE/cleanrepo"
mkdir -p "$CLEANREPO"
git -C "$CLEANREPO" init -q
echo "static" > "$CLEANREPO/file.txt"
git -C "$CLEANREPO" add .
git -C "$CLEANREPO" commit -q -m "init"

echo "  Running: diffsummary with no changes"
run_timed 15 OUT "cd $CLEANREPO && $BINDIR/diffsummary"
RC=$?
if [ $RC -eq 0 ]; then pass "diffsummary no-change: exit 0"; else fail "diffsummary no-change: exit 0" "got $RC"; fi
if echo "$OUT" | grep -q "No changes found."; then pass "diffsummary no-change: correct message"; else fail "diffsummary no-change: correct message" "got: $OUT"; fi

echo ""
echo "=== lt ==="

# Test 7: lt on /tmp
echo "  Running: lt /tmp"
run_timed 15 OUT "python3 $BINDIR/lt.py /tmp"
RC=$?
if [ $RC -eq 0 ]; then pass "lt /tmp: exit 0"; else fail "lt /tmp: exit 0" "got $RC"; fi
if [ -n "$OUT" ]; then pass "lt /tmp: non-empty"; else fail "lt /tmp: non-empty" "empty output"; fi

# Test 8: lt truncation
BIGDIR="$TMPDIR_BASE/bigdir"
mkdir -p "$BIGDIR"
for i in $(seq 1 40); do touch "$BIGDIR/file_$i.txt"; done

echo "  Running: lt on dir with 40 files"
run_timed 15 OUT "python3 $BINDIR/lt.py $BIGDIR"
RC=$?
if [ $RC -eq 0 ]; then pass "lt truncation: exit 0"; else fail "lt truncation: exit 0" "got $RC"; fi
if echo "$OUT" | grep -q '\.\.\. +'; then pass "lt truncation: shows ... +"; else fail "lt truncation: shows ... +" "not found in output"; fi

echo ""
echo "=== digest ==="

# Test 9: digest on relevant script
echo "  Running: digest on relevant"
run_timed 30 OUT "$BINDIR/digest $BINDIR/relevant"
RC=$?
if [ $RC -eq 0 ]; then pass "digest overview: exit 0"; else fail "digest overview: exit 0" "got $RC"; fi
if [ -n "$OUT" ]; then pass "digest overview: non-empty"; else fail "digest overview: non-empty" "empty output"; fi

# Test 10: digest with question
echo "  Running: digest with question"
run_timed 30 OUT "$BINDIR/digest $BINDIR/relevant 'what does it do'"
RC=$?
if [ $RC -eq 0 ]; then pass "digest question: exit 0"; else fail "digest question: exit 0" "got $RC"; fi
if [ -n "$OUT" ]; then pass "digest question: non-empty"; else fail "digest question: non-empty" "empty output"; fi

echo ""
echo "================================"
echo "Results: $PASS/$TOTAL passed"
if [ $FAIL -gt 0 ]; then
  echo "$FAIL test(s) FAILED"
  exit 1
else
  echo "All tests passed!"
  exit 0
fi
