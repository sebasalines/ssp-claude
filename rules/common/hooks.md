# Hooks & Progress Tracking

## Progress Tracking

For multi-step work, use TaskCreate/TaskUpdate to show a checkbox progress display. SSP's `/ssp-run` does this at wave level automatically:

```
☑ Wave 1: layout, sidebar, chat panel (3 tasks)
☐ Wave 2: wire sidebar (1 task)
☐ Verification
☐ Merge to staging branch
☐ Code review
```

Outside of SSP, use progress tasks for any work with 3+ distinct steps so the user can see where things stand.

## Permissions

- Configure allowed tools in `settings.local.json`, not with `dangerously-skip-permissions`
- Enable auto-accept for trusted, well-defined plans
- Disable for exploratory work

## Pre-commit Hook

The project has a pre-git-push hook that runs typecheck across workspaces. Don't bypass it with `--no-verify` — if it fails, fix the type errors.
