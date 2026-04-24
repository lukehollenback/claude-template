---
inject:
  - event: SessionStart
  - event: PreCompact
  - event: PreToolUse
    matcher: mcp__plugin_supabase_supabase__
---

# Supabase Standards

Non-negotiable rules for every interaction with Supabase. Violating them has, in real incidents, taken down production. Read these every time.

---

## 1. NEVER TOUCH THE `main` BRANCH WITHOUT EXPLICIT PERMISSION

The `main` branch of the Supabase project IS production. It backs the live `main` branch of the application. There is no dry-run, no preview, no undo. A dropped function on `main` breaks real signups for real users immediately.

- **NEVER** apply a migration, rename, drop, alter, or any DDL against the `main` Supabase branch unless the user has said, **in the current turn**, explicitly: "run this against main", "apply to prod", or equivalent.
- If the user says "the deployed site is broken" or "Turner hit an error on dev preview," that is NOT permission to touch `main`. Those situations almost certainly mean the `dev` branch needs the change, not `main`.
- Before any DDL: state the branch name and the project ref you intend to target, and ask for confirmation. Wait for a clear "yes" in the chat.
- Data-modifying DML against `main` follows the same rule.

## 2. ALWAYS CONFIRM WHICH BRANCH YOU ARE ON BEFORE ANY SUPABASE CALL

`list_projects` only shows the root project, not its branches. The `main` and `dev` branches are **separate Postgres databases with separate PostgREST instances and separate migration histories.** A project ref like `ordkbrwliuayrkzsfyeq` is `main`; a ref like `bmhxjepaxczjrmulvzhu` is `dev`. They are NOT interchangeable.

Before calling `apply_migration`, `execute_sql`, or any other Supabase MCP tool that mutates state:

1. Call `list_branches` on the root project to enumerate branches and their `project_ref` values.
2. Match the `project_ref` in your intended call to a named branch.
3. State out loud: "I'm about to run X against the `<branch name>` branch (project_ref `<ref>`). Confirm?"
4. Wait for the user to confirm before proceeding.

If a curl dump, log entry, or error message references a hostname like `<ref>.supabase.co`, that `<ref>` identifies the branch. Match it to `list_branches` output before assuming which branch is involved.

## 3. ALWAYS WRITE A MIGRATION FILE BEFORE APPLYING

Every DDL change — including drops, renames, and "just this one quick fix" — must have a corresponding `.sql` file committed to `supabase/migrations/` **before** the `apply_migration` MCP call is made. Migrations applied only via MCP exist in Supabase's migration history table but are absent from the repo, so:

- Fresh environments get provisioned without them.
- Branch promotions silently skip them.
- Another engineer regenerates from source and the schema diverges.

Workflow:

1. Write `NNN_descriptive_name.sql` in `supabase/migrations/`. Use the next sequential number.
2. The `.sql` file contents and the `apply_migration` query must be byte-identical.
3. Apply the migration. Then commit the file.

No exceptions. "I'll add the file later" turns into "prod is broken because the file never got added."

## 4. PROMOTION IS EXPLICIT, NOT IMPLIED

When a change is ready to go from `dev` to `main`:

- The user explicitly requests the promotion.
- Promotion means: apply the same migration files to `main` in the same order, AFTER confirming the dev branch is stable.
- Never promote automatically because "it worked on dev."

## 5. REGENERATE TYPES AFTER FUNCTION/COLUMN CHANGES

Any time a function is added, renamed, dropped, or has its signature changed — or any time a table column changes — regenerate `src/lib/supabase/types.ts` via `generate_typescript_types` and commit it. Stale types will pass local `tsc` and then fail the Vercel build.

## 6. POSTGREST SCHEMA CACHE IS REAL AND SLOW

PostgREST caches the function list. After a DDL change, the cache may take minutes to refresh on Supabase's hosted platform. `NOTIFY pgrst, 'reload schema'` and API restarts do not always help. If you hit PGRST202 "not found in schema cache" immediately after a DDL change, wait. Do not immediately rename/drop/recreate as a workaround — that compounds the problem and leaves debris.

## 7. IF YOU ARE UNSURE, STOP AND ASK

The cost of pausing to confirm is ~15 seconds. The cost of dropping a prod function is hours of scrambling and a broken signup flow for live users. Every time.
