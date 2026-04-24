#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

echo "=== inject-docs ==="

# Use the template's inject-docs.sh directly.
INJECT="$SCRIPT_DIR/../template/scripts/inject-docs.sh"

# Test: SessionStart event outputs global docs (CODING_STANDARDS, RULES).
output="$(echo '{"hook_event_name": "SessionStart"}' | bash "$INJECT")"
assert_contains "SessionStart includes CODING_STANDARDS" "Coding Standards" "$output"
assert_contains "SessionStart includes RULES" "Non-negotiable development rules" "$output"

# Test: SessionStart does NOT output TypeScript standards (requires PreToolUse + matcher).
if echo "$output" | grep -qF "TypeScript Coding Standards"; then
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: SessionStart should not include TypeScript standards"
else
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo "  PASS: SessionStart does not include TypeScript standards"
fi

# Test: PreToolUse with Edit tool outputs TypeScript standards.
output="$(echo '{"hook_event_name": "PreToolUse", "tool_name": "Edit"}' | bash "$INJECT")"
assert_contains "PreToolUse+Edit includes TypeScript standards" \
  "TypeScript Coding Standards" "$output"

# Test: PreToolUse with Edit tool also outputs design standards (glassmorphism).
assert_contains "PreToolUse+Edit includes design standards" \
  "Glassmorphism design system" "$output"

# Test: PreToolUse with a non-matching tool outputs nothing from matcher-guarded docs.
output="$(echo '{"hook_event_name": "PreToolUse", "tool_name": "Read"}' | bash "$INJECT")"
if echo "$output" | grep -qF "TypeScript Coding Standards"; then
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: PreToolUse+Read should not include TypeScript standards"
else
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo "  PASS: PreToolUse+Read does not include TypeScript standards"
fi

# Test: PreCompact event outputs global docs.
output="$(echo '{"hook_event_name": "PreCompact"}' | bash "$INJECT")"
assert_contains "PreCompact includes CODING_STANDARDS" "Coding Standards" "$output"
assert_contains "PreCompact includes RULES" "Non-negotiable development rules" "$output"

# Test: SessionStart includes Supabase standards (rule has no matcher → fires on event alone).
output="$(echo '{"hook_event_name": "SessionStart"}' | bash "$INJECT")"
assert_contains "SessionStart includes Supabase standards" "Supabase Standards" "$output"

# Test: PreToolUse with a Supabase MCP tool name outputs Supabase standards.
output="$(echo '{"hook_event_name": "PreToolUse", "tool_name": "mcp__plugin_supabase_supabase__apply_migration"}' | bash "$INJECT")"
assert_contains "PreToolUse+Supabase MCP includes Supabase standards" \
  "Supabase Standards" "$output"

# Test: PreToolUse with Edit tool does NOT include Supabase standards (matcher is MCP-only).
output="$(echo '{"hook_event_name": "PreToolUse", "tool_name": "Edit"}' | bash "$INJECT")"
if echo "$output" | grep -qF "Supabase Standards"; then
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: PreToolUse+Edit should not include Supabase standards"
else
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo "  PASS: PreToolUse+Edit does not include Supabase standards"
fi

# Test: empty input produces no output and exits cleanly.
output="$(echo '{}' | bash "$INJECT")"
assert_equals "empty event produces no output" "" "$output"

# Test: no input produces no output and exits cleanly.
output="$(echo '' | bash "$INJECT")"
assert_equals "no input produces no output" "" "$output"

print_results
