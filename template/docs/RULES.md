---
description: Non-negotiable development rules for this project. Violating them creates compounding problems — read before any non-trivial work.
inject:
  - event: SessionStart
  - event: PreCompact
---

# Rules

Non-negotiable development rules. Violating them creates compounding problems.

---

## 1. Spec → Test → Code → Commit

Every change flows: **spec → tests → implementation → passing tests → commit.**

- Specs live in `docs/specs/`. They are the single source of truth.
- Specs must be assessed for update on every iteration, even bug fixes.
- Tests verify the spec, not the implementation.
- Every acceptance criterion has at least one test. All tests pass before committing.

## 2. Tests Are Sacred

- Never `skip`, `.only`, comment out, or delete a failing test to make it go away.
- A failing test means: (a) the code is wrong, (b) the test is wrong per spec, or (c) the
  spec is wrong. Resolve explicitly. "Just skip it" is never the answer.
- Tests must be deterministic, independent, and fast.

## 3. Commit After Every Iteration

- One logical change per commit. Don't bundle unrelated changes.
- Commit messages describe the **why**, not just the what. Use periods. Use single quotes
  (double quotes trigger human-in-the-loop). Avoid substitutions.
- Update `.gitignore` before committing → committed secrets/binaries require history rewriting
  to fully remove.

## 4. Fail Fast

Don't code around things that are required. Missing dependency → fail with a clear error.
Unexpected API shape → throw. Missing config → refuse to start. Silent failures compound into
mystery bugs.

## 5. No Duplication

Search the codebase before creating new utilities, helpers, or patterns. Extend or reuse what
exists. Reference existing docs rather than restating them.

## 6. Modularity

Modules communicate through explicit, documented interfaces. Internal implementation details
are private. When an interface changes, update the spec and tests first.

## 7. `.gitignore` Hygiene

Update before every commit. Must ignore: build artifacts, `node_modules/`, `.venv/`, `.env*`,
IDE configs, OS artifacts, generated files reproducible from source.
