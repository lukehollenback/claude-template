#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"
TOOL="$SCRIPT_DIR/../claude-template.sh"

echo "=== init ==="

# Set up a temp directory for test targets.
TEST_TMP="$(mktemp -d)"
trap 'rm -rf "$TEST_TMP"' EXIT

# Test: init creates target directory with global files.
TARGET="$TEST_TMP/project-a"
"$TOOL" init "$TARGET" --profile typescript 2>&1

assert_file_exists "creates .claude/settings.json" "$TARGET/.claude/settings.json"
assert_file_exists "creates docs/CODING_STANDARDS.md" "$TARGET/docs/CODING_STANDARDS.md"
assert_file_exists "creates docs/RULES.md" "$TARGET/docs/RULES.md"
assert_file_exists "creates scripts/inject-docs.sh" "$TARGET/scripts/inject-docs.sh"
assert_file_exists "creates docs/specs directory marker" "$TARGET/docs/specs/.gitkeep"
assert_file_exists "creates .claude-template config" "$TARGET/.claude-template"

# Test: init copies profile files.
assert_file_exists "copies typescript profile file" \
  "$TARGET/docs/CODING_STANDARDS--typescript.md"
assert_file_not_exists "does not copy glassmorphism file" \
  "$TARGET/docs/DESIGN-STANDARDS--glassmorphism.md"

# Test: config has correct profiles.
config_profiles="$(grep '^profiles=' "$TARGET/.claude-template" | cut -d= -f2)"
assert_equals "config lists typescript profile" "typescript" "$config_profiles"

# Test: config has checksums for all managed files.
checksum_count="$(grep -c '^checksum:' "$TARGET/.claude-template")"
assert_equals "config has checksums for all managed files" "5" "$checksum_count"

# Test: init with multiple profiles.
TARGET2="$TEST_TMP/project-b"
"$TOOL" init "$TARGET2" --profile typescript --profile glassmorphism 2>&1

assert_file_exists "copies typescript file with multiple profiles" \
  "$TARGET2/docs/CODING_STANDARDS--typescript.md"
assert_file_exists "copies glassmorphism file with multiple profiles" \
  "$TARGET2/docs/DESIGN-STANDARDS--glassmorphism.md"

config_profiles2="$(grep '^profiles=' "$TARGET2/.claude-template" | cut -d= -f2)"
assert_contains "config lists both profiles" "typescript" "$config_profiles2"
assert_contains "config lists both profiles" "glassmorphism" "$config_profiles2"

# Test: init with no profiles copies only globals.
TARGET3="$TEST_TMP/project-c"
"$TOOL" init "$TARGET3" --no-profiles 2>&1

assert_file_exists "globals copied without profiles" "$TARGET3/docs/CODING_STANDARDS.md"
assert_file_not_exists "no typescript without profile flag" \
  "$TARGET3/docs/CODING_STANDARDS--typescript.md"
assert_file_not_exists "no glassmorphism without profile flag" \
  "$TARGET3/docs/DESIGN-STANDARDS--glassmorphism.md"

# Test: init refuses to overwrite existing project.
output="$("$TOOL" init "$TARGET" --profile typescript 2>&1)" || true
assert_contains "refuses to init existing project" "already exists" "$output"

print_results
