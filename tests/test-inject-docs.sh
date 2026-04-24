#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"

echo "=== inject-docs ==="

# Use the template's inject-docs.sh directly.
INJECT="$SCRIPT_DIR/../template/scripts/inject-docs.sh"

# Helper: assert a TOC line for the given doc has (or lacks) the [injected below] marker.
assert_injected() {
  local desc="$1" doc="$2" output="$3"
  local line
  line="$(echo "$output" | grep -F "\`$doc\`" || true)"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [[ -n "$line" && "$line" == *"[injected below]"* ]]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  PASS: $desc"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  FAIL: $desc"
    echo "    TOC line: $line"
  fi
}

assert_not_injected() {
  local desc="$1" doc="$2" output="$3"
  local line
  line="$(echo "$output" | grep -F "\`$doc\`" || true)"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [[ -n "$line" && "$line" != *"[injected below]"* ]]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  PASS: $desc"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  FAIL: $desc"
    echo "    TOC line: $line"
  fi
}

# --- TOC shape ---

# Test: TOC header always present.
output="$(echo '{"hook_event_name": "SessionStart"}' | bash "$INJECT")"
assert_contains "TOC header present" "# Project Docs" "$output"

# Test: TOC lists every doc in docs/, even ones that don't match this event.
assert_contains "TOC lists CODING_STANDARDS" "\`docs/CODING_STANDARDS.md\`" "$output"
assert_contains "TOC lists RULES" "\`docs/RULES.md\`" "$output"
assert_contains "TOC lists TypeScript standards" "\`docs/CODING_STANDARDS--typescript.md\`" "$output"
assert_contains "TOC lists glassmorphism standards" "\`docs/DESIGN-STANDARDS--glassmorphism.md\`" "$output"
assert_contains "TOC lists Supabase standards" "\`docs/DATABASE-STANDARDS--supabase.md\`" "$output"

# Test: TOC includes descriptions from frontmatter.
assert_contains "TOC includes RULES description" \
  "Non-negotiable development rules for this project" "$output"
assert_contains "TOC includes TypeScript description" \
  "TypeScript and TSX-specific conventions" "$output"

# --- SessionStart injection ---

# CODING_STANDARDS and RULES inject on SessionStart; others don't.
assert_injected "SessionStart injects CODING_STANDARDS" "docs/CODING_STANDARDS.md" "$output"
assert_injected "SessionStart injects RULES" "docs/RULES.md" "$output"
assert_injected "SessionStart injects Supabase standards" "docs/DATABASE-STANDARDS--supabase.md" "$output"
assert_not_injected "SessionStart does not inject TypeScript standards" \
  "docs/CODING_STANDARDS--typescript.md" "$output"
assert_not_injected "SessionStart does not inject glassmorphism" \
  "docs/DESIGN-STANDARDS--glassmorphism.md" "$output"

# Body content of injected docs is present below the TOC.
assert_contains "SessionStart body includes CODING_STANDARDS heading" \
  "# Coding Standards" "$output"
assert_contains "SessionStart body includes RULES heading" "# Rules" "$output"

# --- PreToolUse + Edit ---

output="$(echo '{"hook_event_name": "PreToolUse", "tool_name": "Edit"}' | bash "$INJECT")"
assert_injected "PreToolUse+Edit injects TypeScript standards" \
  "docs/CODING_STANDARDS--typescript.md" "$output"
assert_injected "PreToolUse+Edit injects glassmorphism" \
  "docs/DESIGN-STANDARDS--glassmorphism.md" "$output"
assert_not_injected "PreToolUse+Edit does not inject CODING_STANDARDS" \
  "docs/CODING_STANDARDS.md" "$output"
assert_not_injected "PreToolUse+Edit does not inject Supabase standards" \
  "docs/DATABASE-STANDARDS--supabase.md" "$output"

# Body of injected doc is present.
assert_contains "PreToolUse+Edit body includes TS heading" \
  "# TypeScript Coding Standards" "$output"

# --- PreToolUse + Read (no matches) ---

output="$(echo '{"hook_event_name": "PreToolUse", "tool_name": "Read"}' | bash "$INJECT")"
# TOC still emits, but nothing should be marked injected.
assert_contains "PreToolUse+Read still emits TOC" "# Project Docs" "$output"
assert_not_injected "PreToolUse+Read does not inject TypeScript standards" \
  "docs/CODING_STANDARDS--typescript.md" "$output"
assert_not_injected "PreToolUse+Read does not inject glassmorphism" \
  "docs/DESIGN-STANDARDS--glassmorphism.md" "$output"
# No body content should follow.
if echo "$output" | grep -qF "# TypeScript Coding Standards"; then
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: PreToolUse+Read leaked TS body"
else
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo "  PASS: PreToolUse+Read does not include TS body"
fi

# --- PreCompact ---

output="$(echo '{"hook_event_name": "PreCompact"}' | bash "$INJECT")"
assert_injected "PreCompact injects CODING_STANDARDS" "docs/CODING_STANDARDS.md" "$output"
assert_injected "PreCompact injects RULES" "docs/RULES.md" "$output"

# --- PreToolUse + Supabase MCP ---

output="$(echo '{"hook_event_name": "PreToolUse", "tool_name": "mcp__plugin_supabase_supabase__apply_migration"}' | bash "$INJECT")"
assert_injected "Supabase MCP call injects Supabase standards" \
  "docs/DATABASE-STANDARDS--supabase.md" "$output"
assert_not_injected "Supabase MCP call does not inject TypeScript standards" \
  "docs/CODING_STANDARDS--typescript.md" "$output"

# --- Edge cases ---

# Empty event JSON → no output.
output="$(echo '{}' | bash "$INJECT")"
assert_equals "empty event produces no output" "" "$output"

# Empty stdin → no output.
output="$(echo '' | bash "$INJECT")"
assert_equals "no input produces no output" "" "$output"

print_results
