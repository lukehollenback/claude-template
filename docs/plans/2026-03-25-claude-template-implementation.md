# claude-template Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan
> task-by-task.

**Goal:** Build a bash tool that initializes and syncs Claude Code project directories from a
shared template with profile-based file selection.

**Architecture:** Single bash script (`claude-template.sh`) with subcommands. Template content
lives in `template/`. Per-project `.claude-template` config tracks active profiles and file
checksums for conflict detection. Profile membership determined by `--` filename convention in
`template/docs/`.

**Tech Stack:** Bash, sha256sum/shasum, sed, grep. Tests use a minimal bash test harness.

---

### Task 1: Restructure repository → move template files into `template/`

**Files:**
- Move: `docs/*.md` → `template/docs/*.md`
- Move: `docs/specs/` → `template/docs/specs/`
- Move: `scripts/inject-docs.sh` → `template/scripts/inject-docs.sh`
- Move: `.claude/settings.json` → `template/.claude/settings.json`
- Keep: `docs/plans/` stays at root (these are the tool's own plans, not template content).
- Keep: `.claude/settings.local.json` stays (local-only config).

**Step 1: Create the template directory structure**

```bash
mkdir -p template/.claude template/docs/specs template/scripts
```

**Step 2: Move and rename files**

```bash
# Global docs (no profile suffix).
git mv docs/CODING_STANDARDS.md template/docs/CODING_STANDARDS.md
git mv docs/RULES.md template/docs/RULES.md

# Profile docs (add -- separator).
git mv docs/CODING_STANDARDS-typescript.md template/docs/CODING_STANDARDS--typescript.md
git mv docs/DESIGN-STANDARDS.md template/docs/DESIGN-STANDARDS--glassmorphism.md

# Infrastructure (always global).
git mv scripts/inject-docs.sh template/scripts/inject-docs.sh
git mv .claude/settings.json template/.claude/settings.json
```

**Step 3: Clean up empty directories**

```bash
rmdir scripts
# docs/ stays because docs/plans/ still lives there.
# .claude/ stays because .claude/settings.local.json still lives there.
```

**Step 4: Add a .gitkeep to template/docs/specs/**

```bash
touch template/docs/specs/.gitkeep
```

**Step 5: Commit**

```bash
git add -A
git commit -m 'Restructure repo. Move template content into template/ subdirectory.

Rename profile docs to use -- separator convention:
- CODING_STANDARDS-typescript.md → CODING_STANDARDS--typescript.md
- DESIGN-STANDARDS.md → DESIGN-STANDARDS--glassmorphism.md'
```

---

### Task 2: Create test harness and first test (list-profiles)

**Files:**
- Create: `tests/test-helpers.sh`
- Create: `tests/test-list-profiles.sh`

**Step 1: Write the test harness**

Create `tests/test-helpers.sh` with minimal assertion functions:

```bash
#!/usr/bin/env bash
# Minimal bash test harness.

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

assert_equals() {
  local description="$1" expected="$2" actual="$3"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [[ "$expected" == "$actual" ]]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  PASS: $description"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  FAIL: $description"
    echo "    Expected: $expected"
    echo "    Actual:   $actual"
  fi
}

assert_contains() {
  local description="$1" needle="$2" haystack="$3"
  TESTS_RUN=$((TESTS_RUN + 1))
  if echo "$haystack" | grep -qF "$needle"; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  PASS: $description"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  FAIL: $description"
    echo "    Expected to contain: $needle"
    echo "    Actual: $haystack"
  fi
}

assert_file_exists() {
  local description="$1" filepath="$2"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [[ -f "$filepath" ]]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  PASS: $description"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  FAIL: $description"
    echo "    File not found: $filepath"
  fi
}

assert_file_not_exists() {
  local description="$1" filepath="$2"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [[ ! -f "$filepath" ]]; then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo "  PASS: $description"
  else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo "  FAIL: $description"
    echo "    File should not exist: $filepath"
  fi
}

assert_exit_code() {
  local description="$1" expected="$2" actual="$3"
  assert_equals "$description" "$expected" "$actual"
}

print_results() {
  echo ""
  echo "Results: $TESTS_PASSED/$TESTS_RUN passed, $TESTS_FAILED failed."
  if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
  fi
}
```

**Step 2: Write the failing test for list-profiles**

Create `tests/test-list-profiles.sh`:

```bash
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
```

**Step 3: Run tests to verify they fail**

```bash
chmod +x tests/test-list-profiles.sh tests/test-helpers.sh
bash tests/test-list-profiles.sh
```

Expected: FAIL (claude-template.sh does not exist yet).

**Step 4: Commit**

```bash
git add tests/
git commit -m 'Add test harness and failing tests for list-profiles command.'
```

---

### Task 3: Implement list-profiles command and helper functions

**Files:**
- Create: `claude-template.sh`

**Step 1: Write claude-template.sh with core helpers and list-profiles**

```bash
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
```

**Step 2: Run list-profiles tests**

```bash
chmod +x claude-template.sh
bash tests/test-list-profiles.sh
```

Expected: All PASS.

**Step 3: Commit**

```bash
git add claude-template.sh
git commit -m 'Implement list-profiles command with profile discovery helpers.'
```

---

### Task 4: Write failing tests for init command

**Files:**
- Create: `tests/test-init.sh`

**Step 1: Write test-init.sh**

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"
TOOL="$SCRIPT_DIR/../claude-template.sh"

echo "=== init ==="

# Set up a temp directory for test targets.
TEST_TMP="$(mktemp -d)"
trap 'rm -rf "$TEST_TMP"' EXIT

# Test: init creates target directory with global files.
TARGET="$TEST_TMP/project-a"
"$TOOL" init "$TARGET" --profile typescript 2>&1

assert_file_exists "creates .claude/settings.json" "$TARGET/.claude/settings.json"
assert_file_exists "creates docs/CODING_STANDARDS.md" "$TARGET/docs/CODING_STANDARDS.md"
assert_file_exists "creates docs/RULES.md" "$TARGET/docs/RULES.md"
assert_file_exists "creates scripts/inject-docs.sh" "$TARGET/scripts/inject-docs.sh"
assert_file_exists "creates docs/specs directory marker" "$TARGET/docs/specs/.gitkeep"
assert_file_exists "creates .claude-template config" "$TARGET/.claude-template"

# Test: init copies profile files.
assert_file_exists "copies typescript profile file" \
  "$TARGET/docs/CODING_STANDARDS--typescript.md"
assert_file_not_exists "does not copy glassmorphism file" \
  "$TARGET/docs/DESIGN-STANDARDS--glassmorphism.md"

# Test: config has correct profiles.
config_profiles="$(grep '^profiles=' "$TARGET/.claude-template" | cut -d= -f2)"
assert_equals "config lists typescript profile" "typescript" "$config_profiles"

# Test: config has checksums for all managed files.
checksum_count="$(grep -c '^checksum:' "$TARGET/.claude-template")"
assert_equals "config has checksums for all managed files" "5" "$checksum_count"

# Test: init with multiple profiles.
TARGET2="$TEST_TMP/project-b"
"$TOOL" init "$TARGET2" --profile typescript --profile glassmorphism 2>&1

assert_file_exists "copies typescript file with multiple profiles" \
  "$TARGET2/docs/CODING_STANDARDS--typescript.md"
assert_file_exists "copies glassmorphism file with multiple profiles" \
  "$TARGET2/docs/DESIGN-STANDARDS--glassmorphism.md"

config_profiles2="$(grep '^profiles=' "$TARGET2/.claude-template" | cut -d= -f2)"
assert_contains "config lists both profiles" "typescript" "$config_profiles2"
assert_contains "config lists both profiles" "glassmorphism" "$config_profiles2"

# Test: init with no profiles copies only globals.
TARGET3="$TEST_TMP/project-c"
"$TOOL" init "$TARGET3" --no-profiles 2>&1

assert_file_exists "globals copied without profiles" "$TARGET3/docs/CODING_STANDARDS.md"
assert_file_not_exists "no typescript without profile flag" \
  "$TARGET3/docs/CODING_STANDARDS--typescript.md"
assert_file_not_exists "no glassmorphism without profile flag" \
  "$TARGET3/docs/DESIGN-STANDARDS--glassmorphism.md"

# Test: init refuses to overwrite existing project.
output="$("$TOOL" init "$TARGET" --profile typescript 2>&1)" || true
assert_contains "refuses to init existing project" "already exists" "$output"

print_results
```

**Step 2: Run tests to verify they fail**

```bash
chmod +x tests/test-init.sh
bash tests/test-init.sh
```

Expected: FAIL (cmd_init not implemented).

**Step 3: Commit**

```bash
git add tests/test-init.sh
git commit -m 'Add failing tests for init command.'
```

---

### Task 5: Implement init command

**Files:**
- Modify: `claude-template.sh`

**Step 1: Add config-writing helper and init command**

Add these functions to `claude-template.sh` before the main dispatcher:

```bash
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
  profiles_csv="$(IFS=','; echo "${profiles[*]}")"

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
```

**Step 2: Run init tests**

```bash
bash tests/test-init.sh
```

Expected: All PASS.

**Step 3: Commit**

```bash
git add claude-template.sh
git commit -m 'Implement init command with profile selection and config generation.'
```

---

### Task 6: Write failing tests for sync command

**Files:**
- Create: `tests/test-sync.sh`

**Step 1: Write test-sync.sh**

```bash
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
```

**Step 2: Run tests to verify they fail**

```bash
chmod +x tests/test-sync.sh
bash tests/test-sync.sh
```

Expected: FAIL (cmd_sync not implemented).

**Step 3: Commit**

```bash
git add tests/test-sync.sh
git commit -m 'Add failing tests for sync command.'
```

---

### Task 7: Implement sync command

**Files:**
- Modify: `claude-template.sh`

**Step 1: Add config-reading helpers and sync command**

```bash
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
  grep "^checksum:${rel_path}=" "$config_file" 2>/dev/null | head -1 | \
    sed "s/^checksum:${rel_path}=//"
}

# Update or add a checksum in the config.
# Args: config_file, relative_path, new_hash.
update_checksum() {
  local config_file="$1" rel_path="$2" new_hash="$3"
  if grep -q "^checksum:${rel_path}=" "$config_file" 2>/dev/null; then
    # Use a temp file for portability (sed -i differs across platforms).
    local tmp
    tmp="$(mktemp)"
    sed "s|^checksum:${rel_path}=.*|checksum:${rel_path}=${new_hash}|" \
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
```

**Step 2: Run sync tests**

```bash
bash tests/test-sync.sh
```

Expected: All PASS.

**Step 3: Commit**

```bash
git add claude-template.sh
git commit -m 'Implement sync command with conflict detection and --force flag.'
```

---

### Task 8: Write failing tests for add-profile and remove-profile

**Files:**
- Create: `tests/test-profile-management.sh`

**Step 1: Write test-profile-management.sh**

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test-helpers.sh"
TOOL="$SCRIPT_DIR/../claude-template.sh"

echo "=== add-profile / remove-profile ==="

TEST_TMP="$(mktemp -d)"
trap 'rm -rf "$TEST_TMP"' EXIT

# Start with a project that has only typescript.
TARGET="$TEST_TMP/project"
"$TOOL" init "$TARGET" --profile typescript 2>&1

# Test: add-profile adds glassmorphism.
"$TOOL" add-profile glassmorphism "$TARGET" 2>&1
assert_file_exists "add-profile copies glassmorphism file" \
  "$TARGET/docs/DESIGN-STANDARDS--glassmorphism.md"

config_profiles="$(grep '^profiles=' "$TARGET/.claude-template" | cut -d= -f2)"
assert_contains "config includes glassmorphism" "glassmorphism" "$config_profiles"
assert_contains "config still includes typescript" "typescript" "$config_profiles"

# Test: add-profile rejects unknown profile.
output="$("$TOOL" add-profile nonexistent "$TARGET" 2>&1)" || true
assert_contains "rejects unknown profile" "not found" "$output"

# Test: add-profile rejects already-active profile.
output="$("$TOOL" add-profile typescript "$TARGET" 2>&1)" || true
assert_contains "rejects duplicate profile" "already active" "$output"

# Test: remove-profile removes glassmorphism (with --yes to skip confirmation).
"$TOOL" remove-profile glassmorphism "$TARGET" --yes 2>&1
assert_file_not_exists "remove-profile deletes glassmorphism file" \
  "$TARGET/docs/DESIGN-STANDARDS--glassmorphism.md"

config_profiles="$(grep '^profiles=' "$TARGET/.claude-template" | cut -d= -f2)"
assert_contains "config still has typescript" "typescript" "$config_profiles"

# Glassmorphism should not be in profiles anymore. Use a negative check.
if echo "$config_profiles" | grep -q "glassmorphism"; then
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo "  FAIL: config should not contain glassmorphism"
else
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo "  PASS: config does not contain glassmorphism"
fi

print_results
```

**Step 2: Run to verify failure**

```bash
chmod +x tests/test-profile-management.sh
bash tests/test-profile-management.sh
```

Expected: FAIL.

**Step 3: Commit**

```bash
git add tests/test-profile-management.sh
git commit -m 'Add failing tests for add-profile and remove-profile commands.'
```

---

### Task 9: Implement add-profile and remove-profile commands

**Files:**
- Modify: `claude-template.sh`

**Step 1: Add both commands**

```bash
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

  # Validate profile exists.
  local available
  available="$(discover_profiles)"
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

  # Resolve template.
  local template_repo
  template_repo="$(resolve_template_repo "$target_dir")"
  local tmpl_dir="$template_repo/template"

  # Copy profile files.
  local copied=0
  while IFS= read -r rel_path; do
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
    local dst="$target_dir/$rel_path"
    if [[ -f "$dst" ]]; then
      rm "$dst"
      echo "REMOVED: $rel_path"
      removed=$((removed + 1))
    fi
    # Remove checksum line.
    local tmp
    tmp="$(mktemp)"
    grep -v "^checksum:${rel_path}=" "$config_file" > "$tmp"
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
```

**Step 2: Run profile management tests**

```bash
bash tests/test-profile-management.sh
```

Expected: All PASS.

**Step 3: Commit**

```bash
git add claude-template.sh
git commit -m 'Implement add-profile and remove-profile commands.'
```

---

### Task 10: Create test runner and .gitignore

**Files:**
- Create: `tests/run-all.sh`
- Create: `.gitignore`

**Step 1: Write test runner**

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Running all claude-template tests..."
echo ""

failed=0

for test_file in "$SCRIPT_DIR"/test-*.sh; do
  [[ -f "$test_file" ]] || continue
  echo "--- $(basename "$test_file") ---"
  if bash "$test_file"; then
    echo ""
  else
    failed=$((failed + 1))
    echo ""
  fi
done

if [[ $failed -gt 0 ]]; then
  echo "FAILED: $failed test file(s) had failures."
  exit 1
else
  echo "All test files passed."
fi
```

**Step 2: Write .gitignore**

```
# OS artifacts.
.DS_Store
Thumbs.db

# IDE configs.
.idea/
.vscode/
*.swp
*.swo

# Claude Code local settings (not part of template).
.claude/settings.local.json
```

**Step 3: Run all tests**

```bash
chmod +x tests/run-all.sh
bash tests/run-all.sh
```

Expected: All PASS across all test files.

**Step 4: Commit**

```bash
git add tests/run-all.sh .gitignore
git commit -m 'Add test runner and .gitignore.'
```

---

### Task 11: Write spec document

**Files:**
- Create: `docs/specs/claude-template.md`

**Step 1: Write the spec**

Document the tool's behavior as a specification — commands, arguments, config format, profile
convention, error cases. This is the single source of truth per Rule 1.

Reference the design doc (`docs/plans/2026-03-25-claude-template-tool-design.md`) for
architectural rationale. The spec covers *what* the tool does; the design doc covers *why*.

**Step 2: Commit**

```bash
git add docs/specs/claude-template.md
git commit -m 'Add specification for claude-template tool.'
```

---

### Task 12: Final integration test and cleanup

**Files:**
- Review: all files for consistency.

**Step 1: Run full test suite**

```bash
bash tests/run-all.sh
```

Expected: All PASS.

**Step 2: Manual smoke test**

```bash
# Init a test project.
./claude-template.sh init /tmp/test-project --profile typescript

# Verify files.
ls -la /tmp/test-project/docs/
cat /tmp/test-project/.claude-template

# Sync (should be up to date).
./claude-template.sh sync /tmp/test-project

# Add a profile.
./claude-template.sh add-profile glassmorphism /tmp/test-project

# Remove it.
./claude-template.sh remove-profile glassmorphism /tmp/test-project --yes

# Clean up.
rm -rf /tmp/test-project
```

**Step 3: Commit any fixes, then final commit**

```bash
git add -A
git commit -m 'Final cleanup after integration testing.'
```
