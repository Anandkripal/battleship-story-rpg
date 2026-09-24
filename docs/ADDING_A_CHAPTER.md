# Adding A Chapter

Public demo chapters live in `chapters/demo/`. Private/local chapters should live in `chapters/private/`, which is ignored by Git.

## Basic Shape

```json
{
  "id": "chapter_002",
  "title": "Original Chapter Title",
  "start_event": "opening",
  "events": [
    {
      "id": "opening",
      "kind": "story",
      "text": "Original story text.",
      "next": "first_choice"
    }
  ]
}
```

## Rules

- Every event needs a unique `id`.
- `next`, `true_next`, `false_next`, and choice destinations must point to existing event IDs.
- Use `mechanic` events for gameplay systems.
- Use state paths for flexible progression.
- Reference assets by manifest ID when possible.
- Use `chapter_boundary` when a chapter file ends but the story may continue immediately.

## Chapter Boundaries

Use `kind: "chapter_boundary"` instead of `end` when the boundary needs options:

```json
{
  "id": "chapter_boundary",
  "kind": "chapter_boundary",
  "show_completion": false,
  "mark_complete": true,
  "autosave": true,
  "continue_chapter": "res://chapters/private/chapter_002.json",
  "continue_event": "opening"
}
```

Leave out `continue_chapter` when the chapter should stop at the boundary. Set `show_completion` to `true` only when the player should see a chapter-complete screen.

## Private Content

Do not commit private images, copied text, or reference material. Store local-only chapters in `chapters/private/` and local asset references in `assets/asset_manifest.local.json`.
