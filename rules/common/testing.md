# Testing Requirements

## Minimum Test Coverage: 80%

Test Types (all required where applicable):
1. **Unit Tests** — individual functions, utilities, components
2. **Integration Tests** — API endpoints, database operations
3. **E2E Tests** — critical user flows (Playwright for TS/JS)

## Test-Driven Development

MANDATORY for testable logic. Use ECC's `/everything-claude-code:tdd` skill:
1. Write test first (RED)
2. Run test — it should FAIL
3. Write minimal implementation (GREEN)
4. Run test — it should PASS
5. Refactor (IMPROVE)
6. Verify coverage (80%+)

## Troubleshooting Test Failures

1. Check test isolation — is state leaking between tests?
2. Verify mocks are correct — are they matching actual behavior?
3. Fix implementation, not tests (unless the test is wrong)

## SSP Integration

`/ssp-verify` runs typecheck, tests, build, and lint as a single verification step after plan execution. Each SSP task's acceptance criteria should include testable outcomes where applicable — the executor implements the code, `/ssp-verify` confirms nothing broke.
