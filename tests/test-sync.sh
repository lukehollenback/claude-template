#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"
TOOL="$SCRIPT_DIR/../claude-template.sh"

echo "=== sync ==="

TEST_TMP="$(mktemp -d)"
trap 'rm -rf "$TEST_TMP"' EXIT

# Set up a project to sync.
TARGET="$TEST_TMP/project"
"$TOOL" init "$TARGET" --profile typescript 2>&1

# Save original checksum of a file.
original_checksum="$(grep 'checksum:docs/CODING_STANDARDS.md' \
  "$TARGET/.claude-template" | cut -d= -f2-)"

# Test: sync with no changes lists every file as in sync.
output="$("$TOOL" sync "$TARGET" 2>&1)"
assert_contains "sync reports per-file in-sync status" "UNCHANGED (in sync)" "$output"
assert_contains "sync summary mentions in-sync count" "unchanged (in sync)" "$output"

# Test: sync detects locally modified file and keeps it.
echo "# Local modification" >> "$TARGET/docs/CODING_STANDARDS.md"
output="$("$TOOL" sync "$TARGET" 2>&1)"
assert_contains "sync marks modified file as kept local" "UNCHANGED (kept local)" "$output"
assert_contains "sync mentions the file" "CODING_STANDARDS.md" "$output"
assert_contains "sync prints upstream diff for kept-local file" "Upstream diff" "$output"
assert_contains "sync diff includes the local change" "# Local modification" "$output"
assert_contains "sync summary mentions kept-local count" "unchanged (kept local)" "$output"

# Test: sync --force overwrites modified file.
"$TOOL" sync "$TARGET" --force 2>&1
new_checksum="$(grep 'checksum:docs/CODING_STANDARDS.md' \
  "$TARGET/.claude-template" | cut -d= -f2-)"
assert_equals "force sync restores checksum" "$original_checksum" "$new_checksum"

# Test: sync picks up new template files.
# Create a temporary copy of the template with an extra file, then point the project at it.
FAKE_TEMPLATE="$TEST_TMP/fake-template"
cp -r "$SCRIPT_DIR/.." "$FAKE_TEMPLATE"
echo "# New doc" > "$FAKE_TEMPLATE/template/docs/NEW_DOC.md"
# Update the project config to point at the fake template.
tmp_config="$(mktemp)"
sed "s|^template_repo=.*|template_repo=$FAKE_TEMPLATE|" "$TARGET/.claude-template" > "$tmp_config"
mv "$tmp_config" "$TARGET/.claude-template"
output="$("$TOOL" sync "$TARGET" 2>&1)"
assert_file_exists "sync copies new template file" "$TARGET/docs/NEW_DOC.md"
# Restore original template_repo path for subsequent tests.
tmp_config="$(mktemp)"
sed "s|^template_repo=.*|template_repo=$SCRIPT_DIR/..|" "$TARGET/.claude-template" > "$tmp_config"
mv "$tmp_config" "$TARGET/.claude-template"

# Test: sync without target-dir uses current directory.
cd "$TARGET"
output="$("$TOOL" sync 2>&1)"
assert_contains "sync works from current dir" "Sync complete" "$output"
cd "$SCRIPT_DIR"

print_results
