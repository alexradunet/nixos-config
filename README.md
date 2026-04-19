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
- `pad-nixos` - laptop

### `modules/`

Reusable NixOS modules grouped by purpose.

- `modules/common` - shared base packages and system settings
- `modules/desktop` - GUI / KDE desktop role
- `modules/laptop` - laptop-specific behavior
- `modules/users` - shared user definitions
- `modules/services/*` - reusable service modules
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

Open the repo dev shell with formatter/lint tools:

```bash
nix develop
```

## Notes

- `system.stateVersion` stays host-local
- shared user config lives in Home Manager
- machine-specific overrides should stay small and obvious
- repo-specific binary cache settings live in `flake.nix` via `nixConfig`
- nixpi is intentionally not integrated yet; this repo is preparing the infrastructure first
