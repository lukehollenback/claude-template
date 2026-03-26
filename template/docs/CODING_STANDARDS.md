---
inject:
  - event: SessionStart
  - event: PreCompact
---

# Coding Standards

Language-agnostic standards. For language-specific rules → see `CODING_STANDARDS-{lang}.md`.

---

## Principles

- **Clarity over cleverness.** Code reads like prose. Comments explain *why*, not *what*. Name
  things precisely → a longer accurate name beats a short ambiguous one.
- **No dead code.** No commented-out code, unused imports, or backwards-compatibility shims.
  If it's unused, delete it. Git history exists for a reason.
- **Validate at boundaries, trust internals.** Check user input and external APIs. Don't
  defensively guard against things that can't happen. Errors must be specific and actionable.
- **Evaluate dependencies.** Every dependency is a maintenance liability. Pin versions.
  Update `.gitignore` when adding or removing dependencies.

## Structure

- Group by feature/domain, not by file type (unless the framework dictates otherwise).
- One module, one responsibility.
- Naming conventions are language-specific → see `CODING_STANDARDS-{lang}.md`.

## Error Handling

- Handle errors where you have enough context to do something meaningful.
- Don't catch-and-ignore. Either handle, transform, or re-throw.
- Preserve stack traces. Wrap errors with context but keep the original cause.

## Testing

Workflow governed by `RULES.md` (Rules 1–2). Standards for test code:

- Test names describe expected behavior → "rejects expired tokens" not "calls validateToken."
- One assertion per logical concept. Multiple asserts are fine if they verify one behavior.
- No shared mutable state between tests.
- Prefer real implementations → fakes → stubs → mocks (last resort).
