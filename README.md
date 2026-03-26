# claude-template

[![Tests](https://github.com/lukehollenback/claude-template/actions/workflows/tests.yml/badge.svg)](https://github.com/lukehollenback/claude-template/actions/workflows/tests.yml)

A tool for initializing and syncing [Claude Code](https://claude.ai/claude-code) project
directories from a shared template. Supports selective file inclusion via a profile system.

## Quick Start

```bash
# Clone the template repo.
git clone https://github.com/lukehollenback/claude-template.git

# Initialize a new project with the typescript profile.
./claude-template/claude-template.sh init ~/my-project --profile typescript

# Later, sync updates from the template.
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

- `FILENAME.md` → **global**, always included in every project.
- `FILENAME--<profile>.md` → included only when `<profile>` is active.

Files outside `template/docs/` (`.claude/`, `scripts/`) are always global.

### Current Profiles

| Profile | Files | Description |
|---------|-------|-------------|
| `typescript` | `CODING_STANDARDS--typescript.md` | TypeScript naming, formatting, and component patterns. |
| `glassmorphism` | `DESIGN-STANDARDS--glassmorphism.md` | Glassmorphism design system with tokens and component specs. |

## Template Repo Resolution

When running `sync`, `add-profile`, or `remove-profile`, the tool finds the template repo in
this order:

1. `template_repo=` in the project's `.claude-template` config file.
2. `$CLAUDE_TEMPLATE_DIR` environment variable.
3. Fails with a clear error explaining both options.

## Conflict Detection

On `sync`, the tool compares SHA-256 checksums to detect locally modified files:

- **Unmodified** → safe to overwrite with the latest template version.
- **Modified** → skipped with a warning. Use `--force` to overwrite anyway.
- **New in template** → automatically copied into the project.

## License

Apache 2.0. See [LICENSE](LICENSE).
