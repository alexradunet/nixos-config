# Pi Home Manager notes

This repo manages Pi resources in the native global location:

- `~/.pi/agent/extensions/`
- `~/.pi/agent/prompts/`
- `~/.pi/agent/skills/`
- `~/.pi/agent/themes/`

Bundled resources currently include:

- `pi-web-access` at `~/.pi/agent/extensions/pi-web-access`
- the bundled `librarian` skill at `~/.pi/agent/skills/librarian/SKILL.md`

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
That file is intentionally left mutable and unmanaged so Pi commands like
`/curator` can keep working normally.
