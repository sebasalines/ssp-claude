# Code Comments

## The one rule: explain why, never what

A comment has one job — answer the question a future developer will ask when they stop and stare at this code: *"why is it done this way?"*

If the code already answers that question, the comment is noise. Delete it.

## Write a comment when:

- An external constraint forces a non-obvious decision (rate limits, output size caps, API quirks, framework bugs)
- Something looks wrong but is intentionally correct
- A regex, algorithm, or data structure would take meaningful time to reverse-engineer
- A priority order, fallback chain, or merge strategy was chosen deliberately over alternatives
- A JSDoc describes the *contract* of a function — edge cases, what gets dropped, what wins on conflict — not just a restatement of its name

## Never write a comment that:

- Narrates what the next line does (`// load the font`, `// return the result`)
- Labels a block with a name from a planning session (`// Phase 2`, `// State B`, `// Step 3`)
- Restates a variable or function name in prose (`// array of personality traits`)
- Would be deleted on first code review without anyone missing it

## The test

Before committing a comment, ask: *if someone removed this comment, would a competent developer eventually figure out the code without it?* If yes — delete the comment. If they'd waste time, make a wrong assumption, or repeat a mistake someone already made — keep it.
