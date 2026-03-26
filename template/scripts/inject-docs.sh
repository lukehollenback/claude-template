#!/usr/bin/env bash
#
# inject-docs.sh → Claude Code hook dispatcher.
# Reads hook event JSON from stdin, scans docs/*.md for YAML frontmatter
# with inject rules, and outputs matching files to stdout.
#
# No external dependencies beyond bash, sed, grep.

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

# No event means nothing to match.
if [[ -z "$HOOK_EVENT" ]]; then
  exit 0
fi

# Scan each markdown file in docs/ for inject frontmatter.
for file in "$DOCS_DIR"/*.md; do
  [[ -f "$file" ]] || continue

  # Extract frontmatter (between first --- and second ---).
  # Use awk for portability (BSD sed doesn't support q with trailing commands).
  frontmatter="$(awk 'NR==1 && !/^---$/{exit} NR>1 && /^---$/{print;exit} {print}' "$file")"
  [[ -n "$frontmatter" ]] || continue

  # Check if frontmatter contains any inject rules.
  echo "$frontmatter" | grep -q "inject:" || continue

  # Parse inject rules. Each rule starts with "  - event:".
  # We process rules one at a time.
  matched=false
  current_event=""
  current_matcher=""

  while IFS= read -r line; do
    # New rule starts with "- event:".
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

  # Check the last rule (loop ends without checking it).
  if [[ "$matched" == false && -n "$current_event" && "$current_event" == "$HOOK_EVENT" ]]; then
    if [[ -z "$current_matcher" ]] || echo "$TOOL_NAME" | grep -qE "$current_matcher"; then
      matched=true
    fi
  fi

  if [[ "$matched" == true ]]; then
    cat "$file"
    echo ""
  fi
done

exit 0
