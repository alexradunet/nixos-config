# Pi Home Manager notes

This repo manages Pi resources in the native global location:

- `~/.pi/agent/extensions/`
- `~/.pi/agent/prompts/`
- `~/.pi/agent/skills/`
- `~/.pi/agent/themes/`

## Why not manage `settings.json` yet?

Pi mutates `~/.pi/agent/settings.json` itself for normal workflows like:

- `/settings`
- `pi install`
- changelog/version bookkeeping

A Home Manager-managed `settings.json` would be read-only at runtime.

So for now:

- resource directories are declarative
- mutable Pi state stays Pi-managed

## Future direction

If we want fully declarative Pi settings later, we should likely do it at the
project level with `.pi/settings.json`, or accept that Nix becomes the source of
truth and stop using Pi's imperative settings/package flows on those machines.
