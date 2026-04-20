# nixos-config

Personal multi-host NixOS fleet config.

## Goals

- Keep one repo for all machines
- Reuse shared modules across device types
- Keep host-specific differences small and explicit
- Prepare infrastructure first, so nixpi can be added later cleanly

## Structure

```text
flake.nix                        # flake-parts entrypoint
.github/workflows/               # CI for flake validation
hosts/                           # hardware configs and host-local data
modules/features/nixos/*/        # dendritic NixOS feature modules
modules/features/home/*/         # dendritic Home Manager feature modules
modules/hosts/*.nix              # flake host composition modules
modules/users/*.nix              # user-level feature composition
modules/packages/flake-module.nix# overlay, packages, apps, dev shell, formatter
modules/checks/flake-module.nix  # flake checks
modules/secrets/flake-module.nix # sops-nix exports
pkgs/                            # locally maintained packages, exposed via overlay
secrets/                         # sops-nix secret scaffold
.gitignore                       # ignore build artifacts like result symlinks
```

### `hosts/`

Each host folder now contains only machine-local files such as:

- `hardware-configuration.nix` for machine-specific hardware
- optional host-local files like `syncthing.nix`
- optional untracked `wireguard.private.nix`

Current hosts:

- `evo-nixos` - mini PC / desktop workstation
- `vps-nixos` - canonical VPS / WireGuard hub
- `pad-nixos` - laptop

Each host can also import an optional untracked `wireguard.private.nix` file for local WireGuard role/peer data.
See `hosts/*/wireguard.private.example.nix`.

### `modules/`

This repo now follows a dendritic pattern with flake-parts.

- `modules/features/nixos/*` - reusable exported NixOS features
- `modules/features/home/*` - reusable exported Home Manager features
- `modules/hosts/*.nix` - host composition using exported features and profiles
- `modules/users/*.nix` - user composition using exported home features
- `modules/profiles/nixos/*.nix` - higher-level system profile bundles
- `modules/profiles/home/*.nix` - higher-level home profile bundles
- `modules/secrets/flake-module.nix` - exported `sops-nix` modules
- `modules/packages/flake-module.nix` - overlay, packages, apps, formatter, dev shell
- `modules/checks/flake-module.nix` - flake checks

Notable exported features include:

- `common`, `desktop`, `laptop`
- `role-gaming`, `role-nvidia`
- `service-networkmanager`, `service-openssh`, `service-fail2ban`, `service-syncthing`
- `service-wireguard`, a simple hub-and-spoke overlay built on `networking.wireguard` with the networkd backend
- `service-wg-admin`

Current higher-level profiles include:

- `profile-desktop-workstation`
- `profile-laptop-workstation`
- `profile-server-base`
- `profile-gaming-nvidia`
- `profile-base`
- `profile-host-evo-nixos`
- `profile-host-pad-nixos`
- `profile-host-vps-nixos`

### `pkgs/`

Locally maintained package definitions.

- `pkgs/pi` builds the Pi binary under our control
- local packages are exported through `overlays.default` and reused everywhere as `pkgs.pi` / `pkgs.pi-web-access`
- package version/dependency hashes are pinned in this repo
- see `pkgs/pi/README.md` for the Pi update workflow

### Home Manager

Shared Home Manager config for `alex` is now composed from dendritic home features.

- `modules/users/alex.nix` is the shared entrypoint
- `modules/features/home/*` splits user config by concern
- `modules/features/home/host-*` holds host-specific Home Manager additions
- `modules/features/home/pi/` holds Pi-specific user infrastructure

## WireGuard hub-and-spoke overlay

This repo now includes a small WireGuard module for a simple private overlay:

- one host is the **hub**
- other hosts are **clients/spokes**
- clients route only the overlay subnet through the hub
- the hub keeps the peer inventory
- `vps-nixos` is the canonical hub

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

## wg-admin helper

`vps-nixos` also installs `wg-admin`, a small shell-based helper for runtime peer onboarding.

On `vps-nixos` it keeps peer metadata under:

- `/home/alex/.local/state/wg-admin/peers/`
- generated configs and QR artifacts under `/home/alex/.local/state/wg-admin/generated/`
- generated Nix peer inventory under `/home/alex/.local/state/wg-admin/nix/peers.nix`
- shared defaults in `/etc/wg-admin/config.env`

Typical low-level flow:

```bash
wg-admin list
wg-admin add iphone-alex
wg-admin conf iphone-alex
wg-admin qr iphone-alex
sudo nixos-rebuild switch --flake ~/nixos-config#vps-nixos
```

Higher-level shortcuts:

```bash
wg-admin onboard-mobile iphone-alex --rebuild
wg-admin mobile-page iphone-alex
wg-admin onboard-desktop macbook-alex --rebuild
wg-admin rebuild
```

This helper is intentionally conservative but cleaner than manual copy/paste:

- it generates client configs, QR codes, and a tiny static HTML mobile onboarding page quickly
- it automatically regenerates the dedicated Nix peer inventory file consumed by `hosts/vps-nixos/wireguard.private.nix`
- you still need to rebuild `vps-nixos` after changes so the WireGuard hub picks them up
- `wg-admin nix-snippet <name>` still exists for inspection or manual copy when needed

Pi also gets a bundled `wg-admin` extension + skill so the assistant can use the helper directly on hosts where it is installed, including a higher-level `wg_onboard` tool and `/wg-onboard` command.

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
