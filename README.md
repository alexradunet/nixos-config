# nixos-config

Personal multi-host NixOS fleet config.

## Goals

- Keep one repo for all machines
- Reuse shared modules across device types
- Keep host-specific differences small and explicit
- Prepare infrastructure first, so nixpi can be added later cleanly

## Structure

```text
flake.nix                 # flake entrypoint, overlays, apps, checks, dev shell
.github/workflows/        # CI for flake validation
hosts/                    # real machine definitions
home/                     # Home Manager config for alex
modules/                  # reusable NixOS modules
pkgs/                     # locally maintained packages, exposed via overlay
.gitignore                # ignore build artifacts like result symlinks
```

### `hosts/`

Each host folder contains:

- `default.nix` for host composition and identity
- `hardware-configuration.nix` for machine-specific hardware
- optional host-local files like `syncthing.nix`

Current hosts:

- `evo-nixos` - mini PC / desktop workstation
- `vps-nixos` - canonical VPS / WireGuard hub
- `pad-nixos` - laptop

Each host can also import an optional untracked `wireguard.private.nix` file for local WireGuard role/peer data.
See `hosts/*/wireguard.private.example.nix`.

### `modules/`

Reusable NixOS modules grouped by purpose.

- `modules/common` - shared base packages and system settings
- `modules/desktop` - GUI / KDE desktop role
- `modules/laptop` - laptop-specific behavior
- `modules/users` - shared user definitions
- `modules/services/*` - reusable service modules
  - includes `wireguard`, a simple hub-and-spoke overlay built on `networking.wireguard` with the networkd backend
- `modules/hosts/*` - reusable host-policy modules like boot and unfree

### `pkgs/`

Locally maintained package definitions.

- `pkgs/pi` builds the Pi binary under our control
- local packages are exported through `overlays.default` and reused everywhere as `pkgs.pi` / `pkgs.pi-web-access`
- package version/dependency hashes are pinned in this repo
- see `pkgs/pi/README.md` for the Pi update workflow

### `home/`

Shared Home Manager config for `alex`.

- `home/alex.nix` is the shared entrypoint
- `home/*.nix` splits user config by concern
- `home/hosts/*.nix` holds host-specific Home Manager additions
- `home/pi/` holds Pi-specific user infrastructure

## WireGuard hub-and-spoke overlay

This repo now includes a small WireGuard module for a simple private overlay:

- one host is the **hub**
- other hosts are **clients/spokes**
- clients route only the overlay subnet through the hub
- the hub keeps the peer inventory

Recommended flow:

1. Copy the example file for a host:
   - `hosts/vps-nixos/wireguard.private.example.nix` for the hub
   - `hosts/evo-nixos/wireguard.private.example.nix` for a desktop spoke
   - `hosts/pad-nixos/wireguard.private.example.nix` for a laptop spoke
2. Save it as `wireguard.private.nix`
3. Generate the host key on the host itself:

```bash
sudo install -d -m 700 /var/lib/wireguard
sudo sh -c 'umask 077 && wg genkey > /var/lib/wireguard/<host>.key'
sudo wg pubkey < /var/lib/wireguard/<host>.key
```

4. Put the public key into the hub's peer list and the client's hub config
5. Rebuild the host

This setup intentionally stays simple:

- no full-tunnel `0.0.0.0/0`
- no NAT for internet egress
- no raw full mesh
- `vps-nixos` is the canonical hub in the current layout
- SSH can optionally be exposed only on `wg0`

## Current conventions

### Shared user folders

These are created declaratively:

- `~/Sync`
- `~/Sync/llm-wiki`
- `~/Repos`

### Syncing

Syncthing currently syncs:

- `~/Sync`

Git repos under `~/Repos` are **not** synced with Syncthing.
Use Git/GitHub for those.

## Rebuild

Mini PC:

```bash
sudo nixos-rebuild switch --flake ~/nixos-config#evo-nixos
```

VPS:

```bash
sudo nixos-rebuild switch --flake ~/nixos-config#vps-nixos
```

Laptop:

```bash
sudo nixos-rebuild switch --flake ~/nixos-config#pad-nixos
```

## Quality checks

Format the repo:

```bash
nix fmt
```

Run the flake checks:

```bash
nix flake check --accept-flake-config
```

Run the llm-wiki unit + coverage suite only:

```bash
nix build .#checks.x86_64-linux.llm-wiki-tests
nix build .#checks.x86_64-linux.llm-wiki-home
```

Or locally from the repo dev shell:

```bash
nix develop
cd pkgs/llm-wiki
npm test
npm run test:coverage
```

## Notes

- `system.stateVersion` stays host-local
- shared user config lives in Home Manager
- machine-specific overrides should stay small and obvious
- repo-specific binary cache settings live in `flake.nix` via `nixConfig`
- nixpi is intentionally not integrated yet; this repo is preparing the infrastructure first
