# claude-template Specification

Behavioral specification for the `claude-template` tool. This is the single source of truth
for what the tool does. For rationale and design decisions, see
`docs/plans/2026-03-25-claude-template-tool-design.md`.

## Overview

`claude-template` is a Bash tool that initializes new Claude Code project directories from a
shared template repository and keeps them in sync as the template evolves. It supports selective
file inclusion via a profile system scoped to documentation files.

## Commands

### `init <target-dir> [--profile <name>...] [--no-profiles]`

Initialize a new project from the template.

**Arguments:**
- `<target-dir>` → required. Path to the project directory to create/populate.
- `--profile <name>` → optional, repeatable. Each flag adds a profile by name.
- `--no-profiles` → optional. Skip interactive selection; use no profiles.

**Behavior:**
1. If `<target-dir>/.claude-template` already exists → error, exit 1.
2. If no `--profile` flags and `--no-profiles` not set → interactive mode:
   - Lists discovered profiles with numbered indices.
   - Prompts for comma-separated numbers.
   - Empty input → no profiles selected.
3. Creates directory structure → `.claude/`, `docs/specs/`, `scripts/`.
4. Copies all global files from the template.
5. Copies `.gitkeep` into `docs/specs/` if it exists in the template.
6. Copies profile-specific files for each selected profile.
7. Writes `.claude-template` config with checksums of all copied files.
8. Prints confirmation → `Initialized <target-dir> with profiles: <csv|none>.`

**Error cases:**
- Missing `<target-dir>` → usage message, exit 1.
- `.claude-template` already exists in target → error, exit 1.
- Unknown option → error, exit 1.
- Unexpected positional argument → error, exit 1.

### `sync [<target-dir>] [--force]`

Update a project's managed files from the latest template.

**Arguments:**
- `<target-dir>` → optional, defaults to `.` (current directory).
- `--force` → optional. Overwrite locally modified files without skipping.

**Behavior:**
1. Reads `.claude-template` for `profiles` and stored checksums.
2. Resolves the template repo (see Template Repo Resolution).
3. Computes the full set of managed files for the active profiles.
4. For each managed file:
   - Source missing in template → skip silently.
   - Destination missing in project → copy from template, add checksum, print `ADDED`.
   - Source hash == stored hash AND destination hash == stored hash → skip (up to date).
   - Destination hash == stored hash (not locally modified) → overwrite, update checksum,
     print `UPDATED`.
   - `--force` set → overwrite regardless, update checksum, print `UPDATED`.
   - Otherwise (locally modified) → print `SKIPPED` with advice to use `--force`.
5. Summary line → `Sync complete: N updated, N added, N skipped.`
6. If nothing changed → `All managed files are up to date.`

**Error cases:**
- No `.claude-template` in target → error, exit 1.
- Template repo cannot be resolved → error, exit 1.

### `add-profile <profile> [<target-dir>]`

Add a profile to an existing project.

**Arguments:**
- `<profile>` → required. Profile name to add.
- `<target-dir>` → optional, defaults to `.`.

**Behavior:**
1. Validates profile exists in the template (via auto-discovery).
2. Validates profile is not already active.
3. Copies all files belonging to the profile into the project.
4. Adds checksums for each copied file.
5. Appends profile name to the `profiles` field in `.claude-template`.
6. Prints `ADDED: <path>` for each file, then summary.

**Error cases:**
- Missing `<profile>` argument → usage message, exit 1.
- No `.claude-template` in target → error, exit 1.
- Profile not found in template → error with list of available profiles, exit 1.
- Profile already active → error, exit 1.

### `remove-profile <profile> [<target-dir>] [--yes]`

Remove a profile from an existing project.

**Arguments:**
- `<profile>` → required. Profile name to remove.
- `<target-dir>` → optional, defaults to `.`.
- `--yes` → optional. Skip confirmation prompt.

**Behavior:**
1. Validates profile is currently active.
2. Lists files that will be removed.
3. Unless `--yes` → prompts for confirmation (`y/N`). Anything other than `y`/`Y` aborts.
4. Deletes each profile file from the project, prints `REMOVED: <path>`.
5. Removes corresponding checksum lines from `.claude-template`.
6. Removes profile name from the `profiles` field.
7. Prints summary → `Removed profile '<name>' (N files).`

**Error cases:**
- Missing `<profile>` argument → usage message, exit 1.
- No `.claude-template` in target → error, exit 1.
- Profile not active → error, exit 1.

### `list-profiles`

List all profiles discovered in the template repository.

**Behavior:**
1. Scans `template/docs/` for files matching `*--*.md`.
2. Extracts profile names (the suffix after the last `--`, minus `.md`).
3. Deduplicates and sorts alphabetically.
4. Prints each profile with its constituent files indented beneath it.
5. If no profiles found → prints informational message, exits 0.

## Profile System

### Naming Convention

Files in `template/docs/` use a double-hyphen (`--`) separator:
- `FILENAME.md` → global file, always included.
- `FILENAME--<profile>.md` → profile-specific, included only when `<profile>` is active.

Profile names are derived from the suffix after the last `--` in the filename (minus `.md`).

### Auto-Discovery

Profiles are not registered anywhere. The tool discovers them by scanning `template/docs/` for
files matching the `*--*.md` glob. Results are sorted and deduplicated.

### Scope

Only files in `template/docs/` participate in the profile system. Files in `template/.claude/`
and `template/scripts/` are always global → they are included in every project regardless of
profile selection.

### File Classification

- **Global infrastructure** → `template/.claude/settings.json`, `template/scripts/*`.
- **Global docs** → `template/docs/*.md` where the filename contains no `--`.
- **Profile docs** → `template/docs/*--<profile>.md`.

## Configuration File

The `.claude-template` file lives at the root of each managed project. It is plain text,
line-based, with no quoting or escaping.

### Format

```
# Managed by claude-template. Do not edit checksums manually.
template_repo=/absolute/path/to/claude-template
profiles=typescript,glassmorphism

# Checksums of managed files (used for conflict detection on sync).
checksum:.claude/settings.json=sha256:a1b2c3d4...
checksum:docs/CODING_STANDARDS.md=sha256:b2c3d4e5...
```

### Fields

- `template_repo` → absolute path to the template repository root.
- `profiles` → comma-separated list of active profile names (may be empty).
- `checksum:<relative-path>=sha256:<hex-digest>` → one per managed file.

### Checksum Format

Each checksum line follows the pattern:

```
checksum:<relative-path>=sha256:<64-char-hex-digest>
```

Relative paths are from the project root (e.g., `docs/RULES.md`, `.claude/settings.json`).

## Template Repo Resolution

When operating on an existing project (`sync`, `add-profile`, `remove-profile`), the tool
resolves the template repository in this order:

1. `template_repo=` value in `.claude-template` → used if the path exists and contains a
   `template/` subdirectory.
2. `$CLAUDE_TEMPLATE_DIR` environment variable → used if set and contains a `template/`
   subdirectory.
3. Error → exit 1 with message explaining both options.

For `init` and `list-profiles`, the tool uses its own location (`BASH_SOURCE[0]`) to find the
template repo.

## Conflict Detection

Conflict detection prevents `sync` from silently overwriting local changes.

### Mechanism

- On `init` and `sync`, the tool stores SHA-256 checksums of each managed file.
- On subsequent `sync`, for each file:
  1. Compute current hash of the file in the project → `dst_hash`.
  2. Read stored hash from `.claude-template` → `stored_hash`.
  3. Compute hash of the file in the template → `src_hash`.
  4. If `src_hash == stored_hash` AND `dst_hash == stored_hash` → file unchanged everywhere,
     skip.
  5. If `dst_hash == stored_hash` → file not locally modified, safe to overwrite.
  6. If `dst_hash != stored_hash` → locally modified, skip with warning.
- `--force` overrides step 6 → overwrites regardless.

### SHA-256 Implementation

Uses `sha256sum` (Linux) or `shasum -a 256` (macOS), whichever is available. If neither exists
→ error, exit 1.

## Error Cases Summary

| Condition                              | Command(s)               | Result                  |
|----------------------------------------|--------------------------|-------------------------|
| No command given                       | (top-level)              | Usage message, exit 1   |
| Unknown command                        | (top-level)              | Error + usage, exit 1   |
| Unknown option                         | init, sync, remove       | Error, exit 1           |
| Missing required argument              | init, add, remove        | Usage message, exit 1   |
| `.claude-template` already exists      | init                     | Error, exit 1           |
| `.claude-template` missing             | sync, add, remove        | Error, exit 1           |
| Profile not found in template          | add-profile              | Error + available, exit 1|
| Profile already active                 | add-profile              | Error, exit 1           |
| Profile not active                     | remove-profile           | Error, exit 1           |
| Template repo unresolvable             | sync, add, remove        | Error, exit 1           |
| No SHA-256 tool available              | any (at checksum time)   | Error, exit 1           |
