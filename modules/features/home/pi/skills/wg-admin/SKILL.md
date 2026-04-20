---
name: wg-admin
description: Manage the local wg-admin WireGuard peer registry on the canonical vps-nixos hub. Use when adding a new device, listing peers, generating a client config, exporting a QR code, or producing the Nix peer snippet to copy into the hub inventory.
---

# wg-admin

Use this skill for the lightweight WireGuard onboarding flow in this repo.

## What exists

- Canonical hub host: `vps-nixos`
- CLI tool: `wg-admin`
- Runtime registry on `vps-nixos`: `/home/alex/.local/state/wg-admin`
- Config file: `/etc/wg-admin/config.env`
- Declarative hub inventory consumes a generated peers file from the state dir via the host's private WireGuard config

## Preferred tool path

If the `wg_onboard` or `wg_admin` extension tools are available, prefer them over raw shell commands.

Common actions:

- `wg_onboard` - preferred high-level flow for adding a mobile or desktop peer, with optional rebuild
- `list` - inspect peers before changing anything
- `add <name> [ip]` - create a new peer and generate config
- `show <name>` - inspect peer metadata
- `conf <name>` - print the generated client config
- `qr <name>` - show terminal QR or emit PNG path
- `mobile-page <name>` - emit a tiny static HTML onboarding page path for mobile sharing
- `nix-snippet <name>` - print the peer block for inspection or manual copy
- `enable|disable <name>` - toggle the peer in the runtime registry and regenerate the dedicated Nix peer inventory file
- `sync-nix` - regenerate the dedicated Nix peer inventory file from all enabled peers
- `rebuild` - run the configured `nixos-rebuild` for `vps-nixos`

## Workflow

1. List peers first to avoid duplicate names or conflicting expectations.
2. Add the peer with a descriptive stable name such as `iphone-alex` or `ipad-travel`.
3. Show or export the config / QR code depending on device type.
4. Mention that `wg-admin` also regenerates the dedicated Nix peers file used by `hosts/vps-nixos/wireguard.private.nix`.
5. Remind the user that the hub still needs a rebuild after peer inventory changes so WireGuard picks them up.

## Device-specific guidance

### Mobile devices

Prefer the high-level onboarding flow (`wg_onboard mode=mobile`) so the assistant gets:

- peer creation
- QR PNG path
- tiny HTML onboarding page path
- config path
- optional hub rebuild

If only low-level commands are needed, use QR onboarding:

- terminal QR for immediate scanning
- PNG path when the user wants a file to send or view elsewhere

### Desktop devices

Prefer the high-level onboarding flow (`wg_onboard mode=desktop`) so the assistant gets:

- peer creation
- config path
- optional hub rebuild

If only low-level commands are needed, prefer the generated `.conf` output/path.

## Safety / caveats

- `wg-admin add` stores the generated client private key locally so it can build the config and QR code.
- Treat files under the configured state dir (on `vps-nixos` this is `/home/alex/.local/state/wg-admin`) as sensitive.
- If `wg-admin` is not installed, explain that it is expected on `vps-nixos` and fall back to ordinary repo edits only if the user asks.
