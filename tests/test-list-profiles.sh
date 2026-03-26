#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"
TOOL="$SCRIPT_DIR/../claude-template.sh"

echo "=== list-profiles ==="

# Test: lists discovered profiles.
output="$("$TOOL" list-profiles 2>&1)" || true
assert_contains "lists typescript profile" "typescript" "$output"
assert_contains "lists glassmorphism profile" "glassmorphism" "$output"

# Test: shows files belonging to each profile.
assert_contains "shows typescript file" "CODING_STANDARDS--typescript.md" "$output"
assert_contains "shows glassmorphism file" "DESIGN-STANDARDS--glassmorphism.md" "$output"

print_results
