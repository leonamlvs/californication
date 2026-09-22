# Codex Workflow

Use this file when starting or resuming implementation.

## Rule: one task at a time

For each request, Codex must:

1. Read `00_README.md` and the spec files relevant to the requested task.
2. Read the current implementation before changing it.
3. Implement **only the requested numbered task** from `06_IMPLEMENTATION_TASKS.md`.
4. Preserve all previously completed acceptance criteria.
5. Use primitive/placeholder art unless the task explicitly requires otherwise.
6. Run appropriate Godot CLI validation using `godot`.
7. Fix errors caused by the task.
8. Stop when the task's acceptance criteria and Global Definition of Done are satisfied.
9. Report:
   - files created/changed;
   - tests/checks run;
   - acceptance criteria result;
   - any known limitation that does not block the task.
10. Do **not** begin the next numbered task.

## Architecture guardrails

Do not:

- add scenario-name condition chains to `RunnerController`;
- couple obstacle behavior to model names or art assets;
- create separate input systems per scenario;
- create separate HUD implementations for every device type;
- replace working shared systems with scenario-specific copies;
- add final art/polish while implementing graybox mechanics;
- silently change an agreed spec value or behavior.

If a task exposes a genuine conflict in the spec, document the conflict clearly instead of inventing a permanent design decision.

## Resume protocol

When resuming after another model/session:

1. Inspect repository status and recent changes.
2. Determine the last fully completed task from acceptance evidence, not assumptions.
3. Re-run the relevant validation before editing.
4. Continue from the first incomplete acceptance criterion.

Never redo a completed task unless its acceptance criteria fail.

## Suggested task prompt

```text
Implement Task XX from docs/06_IMPLEMENTATION_TASKS.md.
Follow docs/00_README.md and all relevant specifications.
Implement only this task. Do not start Task XX+1.
Use placeholders/grayboxes where art is required.
Run Godot CLI validation with `godot` and fix task-related errors.
Stop once every acceptance criterion and the Global Definition of Done are satisfied.
Then report changed files, validation performed, acceptance results, and any non-blocking limitation.
```
