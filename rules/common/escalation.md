# Escalation

## The Two-Failure Pivot Rule

When an approach is visibly not producing progress — same error twice, same empty result, same 202 response across many retries — **stop and surface the situation to the user with concrete alternatives.** Do not pile on more retries, longer timeouts, or parallel workers hoping it will eventually work.

**Why:** Fixating on salvaging the original plan wastes the user's time and burns cache. A stalled approach is not a problem to outlast; it's a signal to reconsider. Common pattern: spend 10+ minutes hammering an async endpoint that returns 202, when a totally different (simpler) approach would have worked in 2 minutes — but never tried it because momentum was on the original plan.

**How to apply:**

- **First failure of an approach:** retry once with a small tweak (different auth header, larger timeout, different parameter). This is fine.
- **Second failure with no new information:** stop. State clearly what's failing, why, and propose 2–3 alternative approaches — including simpler/lower-tech ones. Let the user pick. Use `AskUserQuestion` to surface options, not a wall of text.
- **Never let the user's first signal of frustration be the only trigger for a pivot.** Self-escalate before they have to intervene.

## Specific Pivot Signals

Watch for these — they are pivot signals, not retry signals:

- Async endpoints that return 202 indefinitely
- Rate limits hit repeatedly with identical retry behavior
- API calls returning empty/0 data despite success codes (200 but empty payload usually means a different endpoint or query is needed)
- Parallel workers with identical failure modes (means the failure isn't a transient — running more in parallel won't help)
- Three or more identical "command not found" errors after path adjustments — the binary may not be installed or the wrapper assumes a different shell
- Tests that pass locally but fail in CI on the same commit — environmental difference, not a flaky test

## When Persistence IS Right

Don't confuse "persistent" with "stuck." Continuing to retry IS appropriate when:

- Each retry makes measurable progress (more rows ingested, more files processed, more tests green)
- The error message changes between attempts (means investigation is yielding new info)
- A long-running job is genuinely working — checking its status politely is not "retrying"

The rule is about identical failures, not about giving up the moment something doesn't work the first time.

<!-- Origin: feedback_escalate_stalled_approach.md (project memory promotion) -->
