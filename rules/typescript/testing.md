---
paths:
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.js"
  - "**/*.jsx"
---
# TypeScript/JavaScript Testing

> Extends [common/testing.md](../common/testing.md) with TS/JS specifics.

## E2E Testing

Use **Playwright** for critical user flows.

## SSP Task Testing

SSP executors implement code per their task spec. Each task's acceptance criteria should be verifiable — the executor checks its own criteria, and `/ssp-verify` runs the full suite (typecheck, tests, build, lint) after all waves complete.
