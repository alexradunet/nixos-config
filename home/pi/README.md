# Pi Home Manager notes

This repo manages Pi resources in the native global location:

- `~/.pi/agent/extensions/`
- `~/.pi/agent/prompts/`
- `~/.pi/agent/skills/`
- `~/.pi/agent/themes/`

Bundled resources currently include:

- `pi-web-access` at `~/.pi/agent/extensions/pi-web-access`
- `llm-wiki` at `~/.pi/agent/extensions/llm-wiki`
- the bundled `librarian` skill at `~/.pi/agent/skills/librarian/SKILL.md`

## llm-wiki notes

`llm-wiki` stores its wiki under `~/Sync/llm-wiki` so Syncthing can keep it in sync across machines.
This repo exports that location as `PI_LLM_WIKI_DIR`.

The starter is designed to be Obsidian-friendly:

- open `~/Sync/llm-wiki` directly as an Obsidian vault
- use wikilinks and markdown files normally
- use `templates/obsidian/` for reusable page and journal templates
- use `pages/journal/daily/` for journaling

The seeded structure supports both:

- domain-level separation with frontmatter such as `domain: technical` and `domain: personal`
- PARA-style storage under:
  - `pages/projects/`
  - `pages/areas/`
  - `pages/resources/`
  - `pages/archives/`

The wiki also supports optional frontmatter fields:

- `hosts:` for host-specific knowledge
- `domain:` for technical vs personal separation
- `areas:` for long-lived themes and responsibilities

When `hosts` is omitted, knowledge is treated as global. When present, the page applies only to those hosts.

## Why not manage `settings.json` yet?

Pi mutates `~/.pi/agent/settings.json` itself for normal workflows like:

- `/settings`
- `pi install`
- changelog/version bookkeeping

A Home Manager-managed `settings.json` would be read-only at runtime.

So for now:

- resource directories and bundled extension payloads are declarative
- mutable Pi state stays Pi-managed

## Future direction

If we want fully declarative Pi settings later, we should likely do it at the
project level with `.pi/settings.json`, or accept that Nix becomes the source of
truth and stop using Pi's imperative settings/package flows on those machines.

## pi-web-access notes

`pi-web-access` reads its optional runtime config from `~/.pi/web-search.json`.
This repo now seeds a starter config on first activation if the file does not
already exist, then leaves it mutable so Pi commands like `/curator` can keep
working normally.
