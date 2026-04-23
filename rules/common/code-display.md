# Code Display

## Always Show Full Code in Context

When discussing a change to a function, class, or file — **show the full current version** before explaining what changes. Never describe a change abstractly without the reader being able to see what you're talking about.

Rules:
- If changing a function: show the entire function as it exists now, then the new version
- If changing a class: show the full class
- If the file is small enough (< ~150 lines): show the whole file
- If the file is large: show enough surrounding context that the change is unambiguous (at minimum: function signature + full body + any directly referenced helpers)

**Never say things like:**
- "Update the `resolveDetectedFont` function to add a second parameter..."
- "In `BrandFontsPreview`, pass `brandVoice` to the resolution call..."
- "Modify the `execute` function to check for state B..."

...without first showing the current code being referred to.

## Rationale

The user hasn't necessarily read the file being discussed and shouldn't have to go look it up. Show the code, then explain the change. This applies in planning, in conversation, and in implementation.
