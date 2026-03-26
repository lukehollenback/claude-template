#!/usr/bin/env bash
set -euo pipefail

# Resolve the template repo root (where this script lives).
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$REPO_ROOT/template"

# --- Helpers ---

# Portable SHA-256. macOS uses shasum, Linux uses sha256sum.
compute_sha256() {
  local file="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | awk '{print $1}'
  else
    echo "ERROR: No sha256sum or shasum found." >&2
    exit 1
  fi
}

# Discover all profiles by scanning template/docs/ for files with --.
# Outputs one profile name per line, sorted and unique.
discover_profiles() {
  local profile
  for file in "$TEMPLATE_DIR"/docs/*--*.md; do
    [[ -f "$file" ]] || continue
    basename="$(basename "$file" .md)"
    profile="${basename##*--}"
    echo "$profile"
  done | sort -u
}

# List files belonging to a given profile.
# Outputs relative paths (from template/) one per line.
profile_files() {
  local profile="$1"
  for file in "$TEMPLATE_DIR"/docs/*--"${profile}".md; do
    [[ -f "$file" ]] || continue
    echo "docs/$(basename "$file")"
  done
}

# List global doc files (no -- in the name).
global_doc_files() {
  for file in "$TEMPLATE_DIR"/docs/*.md; do
    [[ -f "$file" ]] || continue
    local base
    base="$(basename "$file")"
    if [[ "$base" != *"--"* ]]; then
      echo "docs/$base"
    fi
  done
}

# List all global files (docs + infrastructure).
global_files() {
  global_doc_files

  # Infrastructure files (non-docs, always global).
  if [[ -f "$TEMPLATE_DIR/.claude/settings.json" ]]; then
    echo ".claude/settings.json"
  fi
  for file in "$TEMPLATE_DIR"/scripts/*; do
    [[ -f "$file" ]] || continue
    echo "scripts/$(basename "$file")"
  done
}

# --- Commands ---

cmd_list_profiles() {
  local profiles
  profiles="$(discover_profiles)"

  if [[ -z "$profiles" ]]; then
    echo "No profiles found in $TEMPLATE_DIR/docs/."
    exit 0
  fi

  echo "Available profiles:"
  echo ""
  while IFS= read -r profile; do
    echo "  $profile:"
    profile_files "$profile" | while IFS= read -r f; do
      echo "    - $f"
    done
  done <<< "$profiles"
}

# --- Main dispatcher ---

usage() {
  cat <<'USAGE'
Usage: claude-template <command> [options]

Commands:
  init <target-dir> [--profile <name>...]   Initialize a new project.
  sync [<target-dir>] [--force]             Sync template updates.
  add-profile <profile> [<target-dir>]      Add a profile to a project.
  remove-profile <profile> [<target-dir>]   Remove a profile from a project.
  list-profiles                             List available profiles.
USAGE
}

main() {
  if [[ $# -eq 0 ]]; then
    usage
    exit 1
  fi

  local command="$1"
  shift

  case "$command" in
    list-profiles) cmd_list_profiles "$@" ;;
    init)          cmd_init "$@" ;;
    sync)          cmd_sync "$@" ;;
    add-profile)   cmd_add_profile "$@" ;;
    remove-profile) cmd_remove_profile "$@" ;;
    -h|--help)     usage ;;
    *)
      echo "Unknown command: $command" >&2
      usage >&2
      exit 1
      ;;
  esac
}

main "$@"
