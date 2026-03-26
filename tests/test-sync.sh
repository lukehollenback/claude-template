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

# Test: sync with no changes is a no-op.
output="$("$TOOL" sync "$TARGET" 2>&1)"
assert_contains "sync reports up to date" "up to date" "$output"

# Test: sync detects locally modified file and skips it.
echo "# Local modification" >> "$TARGET/docs/CODING_STANDARDS.md"
output="$("$TOOL" sync "$TARGET" 2>&1)"
assert_contains "sync warns about modified file" "SKIPPED" "$output"
assert_contains "sync mentions the file" "CODING_STANDARDS.md" "$output"

# Test: sync --force overwrites modified file.
"$TOOL" sync "$TARGET" --force 2>&1
new_checksum="$(grep 'checksum:docs/CODING_STANDARDS.md' \
  "$TARGET/.claude-template" | cut -d= -f2-)"
assert_equals "force sync restores checksum" "$original_checksum" "$new_checksum"

# Test: sync picks up new template files.
# Create a fake new global doc in template.
touch "$SCRIPT_DIR/../template/docs/NEW_DOC.md"
echo "# New doc" > "$SCRIPT_DIR/../template/docs/NEW_DOC.md"
output="$("$TOOL" sync "$TARGET" 2>&1)"
assert_file_exists "sync copies new template file" "$TARGET/docs/NEW_DOC.md"
# Clean up fake file.
rm "$SCRIPT_DIR/../template/docs/NEW_DOC.md"

# Test: sync without target-dir uses current directory.
cd "$TARGET"
output="$("$TOOL" sync 2>&1)"
assert_contains "sync works from current dir" "up to date" "$output"
cd "$SCRIPT_DIR"

print_results
