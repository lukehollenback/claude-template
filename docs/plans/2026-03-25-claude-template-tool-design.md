# claude-template Tool Design

## Overview

A bash-based tool for initializing new Claude Code project directories from a shared template
and keeping them in sync as the template evolves. Supports selective file inclusion via a
profile system.

## Repository Layout

```
claude-template/
├── claude-template.sh              # The tool
├── README.md
├── .gitignore
├── template/
│   ├── .claude/
│   │   └── settings.json           # Global → always copied
│   ├── docs/
│   │   ├── CODING_STANDARDS.md              # Global
│   │   ├── CODING_STANDARDS--typescript.md  # Profile: typescript
│   │   ├── DESIGN-STANDARDS--glassmorphism.md  # Profile: glassmorphism
│   │   ├── RULES.md                         # Global
│   │   └── specs/                           # Empty dir, always created
│   └── scripts/
│       └── inject-docs.sh          # Global → always copied
```

## Profile System

### Convention

Files in `template/docs/` use a double-hyphen (`--`) separator to denote profile membership:

- `FILENAME.md` → global, always included.
- `FILENAME--<profile>.md` → included only when `<profile>` is active.

The tool auto-discovers profiles by scanning `template/docs/` for filenames containing `--`
and extracting the suffix after the last `--` (minus `.md`).

### Scope

Only files in `template/docs/` participate in the profile system. Files in `template/.claude/`
and `template/scripts/` are always global.

## Commands

### `claude-template init <target-dir> [--profile <name>...]`

- Creates `<target-dir>` if it doesn't exist.
- Copies all global files from `template/` → `<target-dir>/`.
- Copies profile-specific files for each `--profile` specified.
- If no `--profile` flags → interactive mode: lists profiles, prompts user to select.
- Creates `.claude-template` config in the target.
- Creates `docs/specs/` directory.

### `claude-template sync [<target-dir>]`

- Defaults to current directory if `<target-dir>` omitted.
- Reads `.claude-template` for active profiles and checksums.
- For each managed file:
  - Computes SHA-256 of the file in the target.
  - Compares against stored checksum.
  - **Match** → overwrite with latest template, update checksum.
  - **Mismatch** → warn and skip ("locally modified, use --force").
  - **Missing in target** → new template file → copy and add checksum.
- Files removed from the template → warn but do not delete.
- `--force` → overwrite regardless of local modifications.

### `claude-template add-profile <profile> [<target-dir>]`

- Adds `<profile>` to the project's active profiles in `.claude-template`.
- Copies the profile's files into the project.
- Updates checksums.

### `claude-template remove-profile <profile> [<target-dir>]`

- Removes `<profile>` from active profiles in `.claude-template`.
- Deletes the profile's managed files (with confirmation prompt).
- Removes their checksum entries.

### `claude-template list-profiles`

- Scans `template/docs/` and prints available profiles with the files each includes.

## Configuration File

The `.claude-template` file lives in each target project root:

```
# Managed by claude-template. Do not edit checksums manually.
template_repo=/home/lukeh/developer/claude-template
profiles=typescript,glassmorphism

# Checksums of managed files (used for conflict detection on sync).
checksum:.claude/settings.json=sha256:a1b2c3d4...
checksum:docs/CODING_STANDARDS.md=sha256:b2c3d4e5...
checksum:docs/CODING_STANDARDS--typescript.md=sha256:c3d4e5f6...
checksum:docs/DESIGN-STANDARDS--glassmorphism.md=sha256:d4e5f6g7...
checksum:docs/RULES.md=sha256:e5f6g7h8...
checksum:scripts/inject-docs.sh=sha256:f6g7h8i9...
```

### Template Repo Resolution

The tool locates the template repo in this order:

1. `template_repo=` value in `.claude-template` (relative or absolute path).
2. `$CLAUDE_TEMPLATE_DIR` environment variable.
3. Fail with a clear error explaining both options.

### Conflict Detection

- SHA-256 checksums stored at last sync.
- On sync: current file hash vs. stored hash.
- Match → safe to overwrite. Mismatch → locally modified, skip (unless `--force`).
- This file should be committed to the project repo.

## Technical Decisions

- **Language:** Bash. Maximizes portability across WSL, Ubuntu, macOS, Claude Code cloud
  environments.
- **Dependencies:** Only bash, sha256sum (or shasum on macOS), sed, grep. No Python, no
  external tools.
- **Config format:** Plain text, line-based. No YAML parsing in bash.
- **Profile discovery:** Filename convention with `--` separator. No registry file needed.
- **Non-doc files:** Always global. Profile system scoped to `template/docs/` only.
