---
paths:
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.js"
  - "**/*.jsx"
---
# TypeScript/JavaScript Patterns

> This file extends [common/patterns.md](../common/patterns.md) with TypeScript/JavaScript specific content.

## API Response Format

```typescript
interface ApiResponse<T> {
  success: boolean
  data?: T
  error?: string
  meta?: {
    total: number
    page: number
    limit: number
  }
}
```

## Custom Hooks Pattern

```typescript
export function useDebounce<T>(value: T, delay: number): T {
  const [debouncedValue, setDebouncedValue] = useState<T>(value)

  useEffect(() => {
    const handler = setTimeout(() => setDebouncedValue(value), delay)
    return () => clearTimeout(handler)
  }, [value, delay])

  return debouncedValue
}
```

## Repository Pattern

```typescript
interface Repository<T> {
  findAll(filters?: Filters): Promise<T[]>
  findById(id: string): Promise<T | null>
  create(data: CreateDto): Promise<T>
  update(id: string, data: UpdateDto): Promise<T>
  delete(id: string): Promise<void>
}
```

## Next.js: `next/image` is the hard default

In any Next.js project, **always use `next/image`** for any rendered image asset. This is non-negotiable, not a preference. A bare `<img>` tag is a regression — it gives up:

- LCP optimization (responsive `srcset`, lazy loading, AVIF/WebP, priority hints)
- `images.remotePatterns` / `images.domains` allowlist enforcement (the only XSS defense for stored URLs)
- Layout-shift prevention from explicit `width` / `height`

Rules:
- New code uses `next/image`. Don't reach for `<img>` because it's "easier."
- When extracting a shared image-rendering component (logo, avatar, media tile), the inner element is `<Image>` — not `<img>`. If the component needs hooks or theme awareness that makes `next/image` awkward, design around it (render-prop, sibling component, `as` prop) — don't drop the optimization.
- Removing a `next/image` import is a meaningful change. Treat it as a regression unless there's a specific, documented reason (e.g. animated SVG that `next/image` doesn't handle well) and surface it in the plan.
- `eslint-disable-next-line @next/next/no-img-element` is a smell. Every existing instance is debt — don't add new ones, fix old ones when you touch the file.

Permitted exceptions (rare):
- Inline SVG (`<svg>`), not a raster image — `next/image` doesn't apply.
- Email templates rendered server-side via React Email — `next/image` doesn't run there.
- Test fixtures that explicitly need a bare DOM `<img>`.

If you find yourself writing `<img src={...}>` in app code, stop and either use `next/image` or surface why it's blocked. See `~/.claude/skills/learned/shared-component-replacing-next-image.md` for the deeper rationale on why public-facing pages especially need the optimization.
