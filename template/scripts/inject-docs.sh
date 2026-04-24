#!/usr/bin/env bash
#
# inject-docs.sh → Claude Code hook dispatcher.
# Reads hook event JSON from stdin, scans docs/*.md for YAML frontmatter
# with inject rules, and outputs:
#   1. A semantic TOC of all docs present in docs/ (so Claude can self-pull
#      anything our heuristics miss).
#   2. The full contents of any docs whose inject rules match this event.
#
# No external dependencies beyond bash, sed, grep, awk.

set -euo pipefail

# Resolve docs directory relative to this script's location.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCS_DIR="$(cd "$SCRIPT_DIR/../docs" && pwd)"

# Read stdin (hook event JSON).
INPUT="$(cat)"

# Extract hook_event_name and tool_name from JSON.
# Uses grep -o + sed. Handles missing fields gracefully.
# Note: use [[:space:]] instead of \s for BSD grep/sed compatibility (macOS).
HOOK_EVENT="$(echo "$INPUT" | grep -o '"hook_event_name"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*:.*"\([^"]*\)"/\1/' || true)"
TOOL_NAME="$(echo "$INPUT" | grep -o '"tool_name"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*:.*"\([^"]*\)"/\1/' || true)"

# No event means nothing to do.
if [[ -z "$HOOK_EVENT" ]]; then
  exit 0
fi

# Extract YAML frontmatter (between first --- and second ---) for one file.
extract_frontmatter() {
  local file="$1"
  awk 'NR==1 && !/^---$/{exit} NR>1 && /^---$/{print;exit} {print}' "$file"
}

# Decide whether a frontmatter block's inject rules match the current event.
# Echoes "true" or "false".
matches_event() {
  local frontmatter="$1"
  local current_event=""
  local current_matcher=""
  local matched=false

  while IFS= read -r line; do
    if echo "$line" | grep -q '^[[:space:]]*- event:'; then
      # Check previous rule before starting new one.
      if [[ -n "$current_event" && "$current_event" == "$HOOK_EVENT" ]]; then
        if [[ -z "$current_matcher" ]] || echo "$TOOL_NAME" | grep -qE "$current_matcher"; then
          matched=true
          break
        fi
      fi
      current_event="$(echo "$line" | sed 's/.*event:[[:space:]]*//' | tr -d ' "'"'")"
      current_matcher=""
    elif echo "$line" | grep -q '^[[:space:]]*matcher:'; then
      current_matcher="$(echo "$line" | sed 's/.*matcher:[[:space:]]*//' | tr -d '"'"'")"
    fi
  done <<< "$frontmatter"

  # Check the last rule.
  if [[ "$matched" == false && -n "$current_event" && "$current_event" == "$HOOK_EVENT" ]]; then
    if [[ -z "$current_matcher" ]] || echo "$TOOL_NAME" | grep -qE "$current_matcher"; then
      matched=true
    fi
  fi

  echo "$matched"
}

# Pull a single field's value from a frontmatter block.
# Strips surrounding quotes if present.
extract_field() {
  local frontmatter="$1" field="$2"
  echo "$frontmatter" \
    | grep -E "^${field}:" \
    | head -1 \
    | sed "s/^${field}:[[:space:]]*//" \
    | sed 's/^"\(.*\)"$/\1/' \
    | sed "s/^'\(.*\)'\$/\1/"
}

# --- First pass: scan all docs, build parallel arrays of metadata. ---
# Bash 3.x (default macOS) lacks associative arrays, so use indexed arrays.
DOC_PATHS=()
DOC_DESCS=()
DOC_MATCHED=()

for file in "$DOCS_DIR"/*.md; do
  [[ -f "$file" ]] || continue

  frontmatter="$(extract_frontmatter "$file")"
  # Skip files without frontmatter entirely — they're not part of the system.
  [[ -n "$frontmatter" ]] || continue

  rel_path="docs/$(basename "$file")"
  desc="$(extract_field "$frontmatter" "description")"
  [[ -n "$desc" ]] || desc="(no description)"

  # Only evaluate inject rules if the file has any.
  if echo "$frontmatter" | grep -q "inject:"; then
    matched="$(matches_event "$frontmatter")"
  else
    matched="false"
  fi

  DOC_PATHS+=("$rel_path")
  DOC_DESCS+=("$desc")
  DOC_MATCHED+=("$matched")
done

# Nothing to do if no docs.
[[ ${#DOC_PATHS[@]} -gt 0 ]] || exit 0

# --- Emit TOC. ---
echo "# Project Docs"
echo ""
echo "Available docs in this project. Read any with the Read tool when relevant —"
echo "the heuristics that auto-inject below may miss your specific situation."
echo ""
i=0
while [[ $i -lt ${#DOC_PATHS[@]} ]]; do
  if [[ "${DOC_MATCHED[$i]}" == "true" ]]; then
    echo "- \`${DOC_PATHS[$i]}\` [injected below] — ${DOC_DESCS[$i]}"
  else
    echo "- \`${DOC_PATHS[$i]}\` — ${DOC_DESCS[$i]}"
  fi
  i=$((i + 1))
done
echo ""

# --- Emit full content of matched docs. ---
i=0
while [[ $i -lt ${#DOC_PATHS[@]} ]]; do
  if [[ "${DOC_MATCHED[$i]}" == "true" ]]; then
    echo "---"
    echo ""
    cat "$DOCS_DIR/$(basename "${DOC_PATHS[$i]}")"
    echo ""
  fi
  i=$((i + 1))
done

exit 0
