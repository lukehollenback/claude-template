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
  local profile base_name
  for file in "$TEMPLATE_DIR"/docs/*--*.md; do
    [[ -f "$file" ]] || continue
    base_name="$(basename "$file" .md)"
    profile="${base_name##*--}"
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
  local profiles_csv=""
  local no_profiles=false

  # Parse arguments. Build a comma-separated profile string directly
  # to avoid bash 3.x issues with empty arrays under set -u.
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --profile)
        if [[ $# -lt 2 ]]; then
          echo "ERROR: --profile requires a value." >&2
          exit 1
        fi
        shift
        if [[ -n "$profiles_csv" ]]; then
          profiles_csv="$profiles_csv,$1"
        else
          profiles_csv="$1"
        fi
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
  if [[ -z "$profiles_csv" && "$no_profiles" == false ]]; then
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
            if [[ -n "$profiles_csv" ]]; then
              profiles_csv="$profiles_csv,$selected"
            else
              profiles_csv="$selected"
            fi
          fi
        done
      fi
    fi
  fi

  # Validate requested profiles exist.
  if [[ -n "$profiles_csv" ]]; then
    local available
    available="$(discover_profiles)"
    IFS=',' read -ra requested <<< "$profiles_csv"
    for profile in "${requested[@]}"; do
      if ! echo "$available" | grep -qx "$profile"; then
        echo "ERROR: Profile '$profile' not found." >&2
        echo "Available profiles: $(echo "$available" | tr '\n' ', ' | sed 's/,$//')" >&2
        exit 1
      fi
    done
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
  if [[ -n "$profiles_csv" ]]; then
    IFS=',' read -ra profile_list <<< "$profiles_csv"
    for profile in "${profile_list[@]}"; do
      while IFS= read -r rel_path; do
        local src="$TEMPLATE_DIR/$rel_path"
        local dst="$target_dir/$rel_path"
        mkdir -p "$(dirname "$dst")"
        cp "$src" "$dst"
      done <<< "$(profile_files "$profile")"
    done
  fi

  # Write config.
  write_config "$target_dir" "$profiles_csv"

  echo "Initialized $target_dir with profiles: ${profiles_csv:-none}."
}

# Read a value from the .claude-template config.
# Args: config_file, key.
read_config() {
  local config_file="$1" key="$2"
  grep "^${key}=" "$config_file" 2>/dev/null | head -1 | cut -d= -f2-
}

# Read a checksum from config.
# Args: config_file, relative_path.
read_checksum() {
  local config_file="$1" rel_path="$2"
  # Escape special regex characters in the path for grep.
  local escaped_path
  escaped_path="$(printf '%s' "$rel_path" | sed 's/[.[\*^$()+?{|]/\\&/g')"
  grep "^checksum:${escaped_path}=" "$config_file" 2>/dev/null | head -1 | \
    cut -d= -f2-
}

# Update or add a checksum in the config.
# Args: config_file, relative_path, new_hash.
update_checksum() {
  local config_file="$1" rel_path="$2" new_hash="$3"
  # Escape special regex characters in the path for sed matching.
  local escaped_path
  escaped_path="$(printf '%s' "$rel_path" | sed 's/[.[\*^$()+?{|]/\\&/g')"
  if grep -q "^checksum:${escaped_path}=" "$config_file" 2>/dev/null; then
    # Use a temp file for portability (sed -i differs across platforms).
    local tmp
    tmp="$(mktemp)"
    sed "s|^checksum:${escaped_path}=.*|checksum:${rel_path}=${new_hash}|" \
      "$config_file" > "$tmp"
    mv "$tmp" "$config_file"
  else
    echo "checksum:${rel_path}=${new_hash}" >> "$config_file"
  fi
}

# Resolve the template repo for an existing project.
# Args: target_dir.
resolve_template_repo() {
  local target_dir="$1"
  local config_file="$target_dir/.claude-template"

  # 1. Config file value.
  local repo
  repo="$(read_config "$config_file" "template_repo")"
  if [[ -n "$repo" && -d "$repo/template" ]]; then
    echo "$repo"
    return
  fi

  # 2. Environment variable.
  if [[ -n "${CLAUDE_TEMPLATE_DIR:-}" && -d "$CLAUDE_TEMPLATE_DIR/template" ]]; then
    echo "$CLAUDE_TEMPLATE_DIR"
    return
  fi

  # 3. Fail.
  echo "ERROR: Cannot find template repo." >&2
  echo "Set template_repo in .claude-template or \$CLAUDE_TEMPLATE_DIR." >&2
  exit 1
}

cmd_sync() {
  local target_dir=""
  local force=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --force) force=true ;;
      -*) echo "Unknown option: $1" >&2; exit 1 ;;
      *) target_dir="$1" ;;
    esac
    shift
  done

  target_dir="${target_dir:-.}"
  local config_file="$target_dir/.claude-template"

  if [[ ! -f "$config_file" ]]; then
    echo "ERROR: No .claude-template found in $target_dir." >&2
    echo "Run 'claude-template init' first." >&2
    exit 1
  fi

  # Resolve template repo (may differ from REPO_ROOT if run from installed location).
  local template_repo
  template_repo="$(resolve_template_repo "$target_dir")"
  local tmpl_dir="$template_repo/template"

  local profiles
  profiles="$(read_config "$config_file" "profiles")"

  local skipped=0
  local updated=0
  local added=0

  # Build list of expected managed files.
  local expected_files
  expected_files="$(TEMPLATE_DIR="$tmpl_dir" managed_files_for_profiles "$profiles")"

  while IFS= read -r rel_path; do
    [[ -n "$rel_path" ]] || continue
    local src="$tmpl_dir/$rel_path"
    local dst="$target_dir/$rel_path"

    if [[ ! -f "$src" ]]; then
      continue
    fi

    local src_hash
    src_hash="sha256:$(compute_sha256 "$src")"

    if [[ ! -f "$dst" ]]; then
      # New file from template.
      mkdir -p "$(dirname "$dst")"
      cp "$src" "$dst"
      update_checksum "$config_file" "$rel_path" "$src_hash"
      echo "ADDED: $rel_path"
      added=$((added + 1))
      continue
    fi

    local dst_hash
    dst_hash="sha256:$(compute_sha256 "$dst")"
    local stored_hash
    stored_hash="$(read_checksum "$config_file" "$rel_path")"

    # If source hasn't changed from what's stored, nothing to do.
    if [[ "$src_hash" == "$stored_hash" && "$dst_hash" == "$stored_hash" ]]; then
      continue
    fi

    # If destination matches stored hash, it hasn't been locally modified → safe to update.
    if [[ "$dst_hash" == "$stored_hash" || "$force" == true ]]; then
      cp "$src" "$dst"
      update_checksum "$config_file" "$rel_path" "$src_hash"
      echo "UPDATED: $rel_path"
      updated=$((updated + 1))
    else
      echo "SKIPPED: $rel_path (locally modified, use --force to overwrite)."
      skipped=$((skipped + 1))
    fi
  done <<< "$expected_files"

  if [[ $updated -eq 0 && $added -eq 0 && $skipped -eq 0 ]]; then
    echo "All managed files are up to date."
  else
    echo ""
    echo "Sync complete: $updated updated, $added added, $skipped skipped."
  fi
}

cmd_add_profile() {
  local profile="${1:-}"
  local target_dir="${2:-.}"

  if [[ -z "$profile" ]]; then
    echo "Usage: claude-template add-profile <profile> [<target-dir>]" >&2
    exit 1
  fi

  local config_file="$target_dir/.claude-template"
  if [[ ! -f "$config_file" ]]; then
    echo "ERROR: No .claude-template found in $target_dir." >&2
    exit 1
  fi

  # Resolve template.
  local template_repo
  template_repo="$(resolve_template_repo "$target_dir")"
  local tmpl_dir="$template_repo/template"

  # Validate profile exists.
  local available
  available="$(TEMPLATE_DIR="$tmpl_dir" discover_profiles)"
  if ! echo "$available" | grep -qx "$profile"; then
    echo "ERROR: Profile '$profile' not found." >&2
    echo "Available profiles: $(echo "$available" | tr '\n' ', ' | sed 's/,$//')" >&2
    exit 1
  fi

  # Check not already active.
  local current
  current="$(read_config "$config_file" "profiles")"
  if echo ",$current," | grep -q ",$profile,"; then
    echo "ERROR: Profile '$profile' is already active." >&2
    exit 1
  fi

  # Copy profile files.
  local copied=0
  while IFS= read -r rel_path; do
    [[ -n "$rel_path" ]] || continue
    local src="$tmpl_dir/$rel_path"
    local dst="$target_dir/$rel_path"
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    local hash
    hash="sha256:$(compute_sha256 "$dst")"
    update_checksum "$config_file" "$rel_path" "$hash"
    echo "ADDED: $rel_path"
    copied=$((copied + 1))
  done <<< "$(TEMPLATE_DIR="$tmpl_dir" profile_files "$profile")"

  # Update profiles list.
  local new_profiles
  if [[ -n "$current" ]]; then
    new_profiles="$current,$profile"
  else
    new_profiles="$profile"
  fi
  local tmp
  tmp="$(mktemp)"
  sed "s/^profiles=.*/profiles=$new_profiles/" "$config_file" > "$tmp"
  mv "$tmp" "$config_file"

  echo "Added profile '$profile' ($copied files)."
}

cmd_remove_profile() {
  local profile=""
  local target_dir="."
  local skip_confirm=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --yes) skip_confirm=true ;;
      -*) echo "Unknown option: $1" >&2; exit 1 ;;
      *)
        if [[ -z "$profile" ]]; then
          profile="$1"
        else
          target_dir="$1"
        fi
        ;;
    esac
    shift
  done

  if [[ -z "$profile" ]]; then
    echo "Usage: claude-template remove-profile <profile> [<target-dir>] [--yes]" >&2
    exit 1
  fi

  local config_file="$target_dir/.claude-template"
  if [[ ! -f "$config_file" ]]; then
    echo "ERROR: No .claude-template found in $target_dir." >&2
    exit 1
  fi

  # Verify profile is active.
  local current
  current="$(read_config "$config_file" "profiles")"
  if ! echo ",$current," | grep -q ",$profile,"; then
    echo "ERROR: Profile '$profile' is not active." >&2
    exit 1
  fi

  # Resolve template.
  local template_repo
  template_repo="$(resolve_template_repo "$target_dir")"
  local tmpl_dir="$template_repo/template"

  # List files that will be removed.
  local files_to_remove
  files_to_remove="$(TEMPLATE_DIR="$tmpl_dir" profile_files "$profile")"

  if [[ "$skip_confirm" == false ]]; then
    echo "Will remove these files:"
    echo "$files_to_remove" | while IFS= read -r f; do echo "  - $f"; done
    echo ""
    echo "Continue? [y/N]"
    read -r answer
    if [[ "$answer" != "y" && "$answer" != "Y" ]]; then
      echo "Aborted."
      exit 0
    fi
  fi

  # Remove files and checksums.
  local removed=0
  while IFS= read -r rel_path; do
    [[ -n "$rel_path" ]] || continue
    local dst="$target_dir/$rel_path"
    if [[ -f "$dst" ]]; then
      rm "$dst"
      echo "REMOVED: $rel_path"
      removed=$((removed + 1))
    fi
    # Remove checksum line (escape dots/special chars for grep).
    local escaped_path
    escaped_path="$(printf '%s' "$rel_path" | sed 's/[.[\*^$()+?{|]/\\&/g')"
    local tmp
    tmp="$(mktemp)"
    grep -v "^checksum:${escaped_path}=" "$config_file" > "$tmp" || true
    mv "$tmp" "$config_file"
  done <<< "$files_to_remove"

  # Update profiles list (remove this profile).
  local new_profiles
  new_profiles="$(echo "$current" | tr ',' '\n' | grep -v "^${profile}$" | \
    tr '\n' ',' | sed 's/,$//')"
  local tmp
  tmp="$(mktemp)"
  sed "s/^profiles=.*/profiles=$new_profiles/" "$config_file" > "$tmp"
  mv "$tmp" "$config_file"

  echo "Removed profile '$profile' ($removed files)."
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
