#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"
TOOL="$SCRIPT_DIR/../claude-template.sh"

echo "=== add-profile / remove-profile ==="

TEST_TMP="$(mktemp -d)"
trap 'rm -rf "$TEST_TMP"' EXIT

# Start with a project that has only typescript.
TARGET="$TEST_TMP/project"
"$TOOL" init "$TARGET" --profile typescript 2>&1

# Test: add-profile adds glassmorphism.
"$TOOL" add-profile glassmorphism "$TARGET" 2>&1
assert_file_exists "add-profile copies glassmorphism file" \
  "$TARGET/docs/DESIGN-STANDARDS--glassmorphism.md"

config_profiles="$(grep '^profiles=' "$TARGET/.claude-template" | cut -d= -f2)"
assert_contains "config includes glassmorphism" "glassmorphism" "$config_profiles"
assert_contains "config still includes typescript" "typescript" "$config_profiles"

# Test: add-profile rejects unknown profile.
output="$("$TOOL" add-profile nonexistent "$TARGET" 2>&1)" || true
assert_contains "rejects unknown profile" "not found" "$output"

# Test: add-profile rejects already-active profile.
output="$("$TOOL" add-profile typescript "$TARGET" 2>&1)" || true
assert_contains "rejects duplicate profile" "already active" "$output"

# Test: remove-profile removes glassmorphism (with --yes to skip confirmation).
"$TOOL" remove-profile glassmorphism "$TARGET" --yes 2>&1
assert_file_not_exists "remove-profile deletes glassmorphism file" \
  "$TARGET/docs/DESIGN-STANDARDS--glassmorphism.md"

config_profiles="$(grep '^profiles=' "$TARGET/.claude-template" | cut -d= -f2)"
assert_contains "config still has typescript" "typescript" "$config_profiles"

# Glassmorphism should not be in profiles anymore. Use a negative check.
if echo "$config_profiles" | grep -q "glassmorphism"; then
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: config should not contain glassmorphism"
else
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo "  PASS: config does not contain glassmorphism"
fi

print_results
