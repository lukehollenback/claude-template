# claude-template

[![Tests](https://github.com/lukehollenback/claude-template/actions/workflows/tests.yml/badge.svg)](https://github.com/lukehollenback/claude-template/actions/workflows/tests.yml)

A tool for initializing and syncing [Claude Code](https://claude.ai/claude-code) project
directories with a spec-driven development system. Supports selective file inclusion via
a profile system.

## Quick Start


### Step 1: Clone this repository.

```bash
git clone https://github.com/lukehollenback/claude-template.git
```

### Step 2: Initialize a new project with the TypeScript profile.

```bash
./claude-template/claude-template.sh init ~/my-project --profile typescript
```

### Step 3: Later, sync updates from the template.
./claude-template/claude-template.sh sync ~/my-project
```

## Commands

### `init <target-dir> [--profile <name>...] [--no-profiles]`

Initialize a new project directory. Copies global template files and any requested profile
files. Creates a `.claude-template` config in the target for future syncs.

```bash
# Interactive → prompts you to select profiles.
./claude-template.sh init ~/my-project

# Explicit profiles.
./claude-template.sh init ~/my-project --profile typescript --profile glassmorphism

# No profiles → globals only.
./claude-template.sh init ~/my-project --no-profiles
```

### `sync [<target-dir>] [--force]`

Update managed files in an existing project. Detects local modifications via SHA-256
checksums and skips them by default.

```bash
# Sync from the project directory.
cd ~/my-project && claude-template.sh sync

# Sync a specific directory.
./claude-template.sh sync ~/my-project

# Force overwrite locally modified files.
./claude-template.sh sync ~/my-project --force
```

### `add-profile <profile> [<target-dir>]`

Add a profile to an existing project. Copies the profile's files and updates the config.

```bash
./claude-template.sh add-profile glassmorphism ~/my-project
```

### `remove-profile <profile> [<target-dir>] [--yes]`

Remove a profile from an existing project. Deletes the profile's files and updates the
config. Prompts for confirmation unless `--yes` is passed.

```bash
./claude-template.sh remove-profile glassmorphism ~/my-project --yes
```

### `list-profiles`

Show available profiles and which files they include.

```bash
./claude-template.sh list-profiles
```

## Profile System

Files in `template/docs/` use a double-hyphen (`--`) naming convention:

- `FILENAME.md` → **Global** and always included in every project.
- `FILENAME--<profile>.md` → Included only when `<profile>` is active.

Files outside `template/docs/` (e.g., `.claude/`, `scripts/`) are always global.

## Template Repo Resolution

When running `sync`, `add-profile`, or `remove-profile`, the tool finds the template repo in
this order:

1. `template_repo=` in the project's `.claude-template` config file.
2. `$CLAUDE_TEMPLATE_DIR` environment variable.
3. Fails with a clear error explaining both options.

## Conflict Detection

On `sync`, the tool compares SHA-256 checksums to detect locally modified files:

- **Unmodified** → Safe to overwrite with the latest template version.
- **Modified** → Skipped with a warning. Use `--force` to overwrite anyway.
- **New in template** → Automatically copied into the project.
