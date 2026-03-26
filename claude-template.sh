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

# --- Composite helpers ---

# List all managed files for a set of profiles (comma-separated).
# Outputs relative paths, one per line.
managed_files_for_profiles() {
  local profiles="$1"

  # Always include globals.
  global_files

  # Include profile-specific files.
  if [[ -n "$profiles" ]]; then
    IFS=',' read -ra profile_arr <<< "$profiles"
    for profile in "${profile_arr[@]}"; do
      profile_files "$profile"
    done
  fi
}

# Write the .claude-template config file.
# Args: target_dir, profiles (comma-separated).
write_config() {
  local target_dir="$1" profiles="$2"
  local config_file="$target_dir/.claude-template"

  cat > "$config_file" <<EOF
# Managed by claude-template. Do not edit checksums manually.
template_repo=$REPO_ROOT
profiles=$profiles

# Checksums of managed files (used for conflict detection on sync).
EOF

  # Add checksums for all managed files.
  while IFS= read -r rel_path; do
    local full_path="$target_dir/$rel_path"
    if [[ -f "$full_path" ]]; then
      local hash
      hash="$(compute_sha256 "$full_path")"
      echo "checksum:${rel_path}=sha256:${hash}" >> "$config_file"
    fi
  done <<< "$(managed_files_for_profiles "$profiles")"
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

cmd_init() {
  local target_dir=""
  local profiles=()
  local no_profiles=false

  # Parse arguments.
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --profile)
        shift
        profiles+=("$1")
        ;;
      --no-profiles)
        no_profiles=true
        ;;
      -*)
        echo "Unknown option: $1" >&2
        exit 1
        ;;
      *)
        if [[ -z "$target_dir" ]]; then
          target_dir="$1"
        else
          echo "Unexpected argument: $1" >&2
          exit 1
        fi
        ;;
    esac
    shift
  done

  if [[ -z "$target_dir" ]]; then
    echo "Usage: claude-template init <target-dir> [--profile <name>...]" >&2
    exit 1
  fi

  # Refuse to overwrite existing project.
  if [[ -f "$target_dir/.claude-template" ]]; then
    echo "ERROR: $target_dir already exists as a claude-template project." >&2
    echo "Use 'claude-template sync' to update it." >&2
    exit 1
  fi

  # Interactive profile selection if no --profile and no --no-profiles.
  if [[ ${#profiles[@]} -eq 0 && "$no_profiles" == false ]]; then
    local available
    available="$(discover_profiles)"
    if [[ -n "$available" ]]; then
      echo "Available profiles:"
      local i=1
      while IFS= read -r p; do
        echo "  $i) $p"
        i=$((i + 1))
      done <<< "$available"
      echo ""
      echo "Enter profile numbers (comma-separated), or press Enter for none:"
      read -r selection
      if [[ -n "$selection" ]]; then
        IFS=',' read -ra nums <<< "$selection"
        local profile_list
        profile_list="$(echo "$available" | head -n 999)"
        for num in "${nums[@]}"; do
          num="$(echo "$num" | tr -d ' ')"
          local selected
          selected="$(echo "$profile_list" | sed -n "${num}p")"
          if [[ -n "$selected" ]]; then
            profiles+=("$selected")
          fi
        done
      fi
    fi
  fi

  # Build comma-separated profile string.
  local profiles_csv=""
  if [[ ${#profiles[@]} -gt 0 ]]; then
    profiles_csv="$(IFS=','; echo "${profiles[*]}")"
  fi

  # Create directory structure.
  mkdir -p "$target_dir/.claude" "$target_dir/docs/specs" "$target_dir/scripts"

  # Copy global files.
  while IFS= read -r rel_path; do
    local src="$TEMPLATE_DIR/$rel_path"
    local dst="$target_dir/$rel_path"
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
  done <<< "$(global_files)"

  # Copy .gitkeep for specs.
  if [[ -f "$TEMPLATE_DIR/docs/specs/.gitkeep" ]]; then
    cp "$TEMPLATE_DIR/docs/specs/.gitkeep" "$target_dir/docs/specs/.gitkeep"
  fi

  # Copy profile files.
  for profile in "${profiles[@]}"; do
    while IFS= read -r rel_path; do
      local src="$TEMPLATE_DIR/$rel_path"
      local dst="$target_dir/$rel_path"
      mkdir -p "$(dirname "$dst")"
      cp "$src" "$dst"
    done <<< "$(profile_files "$profile")"
  done

  # Write config.
  write_config "$target_dir" "$profiles_csv"

  echo "Initialized $target_dir with profiles: ${profiles_csv:-none}."
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
