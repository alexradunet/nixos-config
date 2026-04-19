# pi-llm-wiki

A Pi extension for a local, syncable LLM wiki.

It provides these tools:

- `wiki_status`
- `wiki_capture`
- `wiki_search`
- `wiki_ensure_page`
- `wiki_lint`
- `wiki_rebuild`

## Storage path

By default it stores wiki data under `~/Sync/llm-wiki`.
You can override that with `PI_LLM_WIKI_DIR`.

## Host-specific knowledge

Pages and captured sources may include an optional frontmatter field:

```yaml
hosts:
  - pad-nixos
```

If `hosts` is omitted, the page is global.
If `hosts` is present, the page applies only to those hosts.

`wiki_search` defaults to the current host scope plus global pages.
The current host can be overridden with `PI_LLM_WIKI_HOST` if needed.
