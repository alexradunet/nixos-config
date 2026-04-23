# NixPI infrastructure

Personal multi-host NixOS fleet config.

## Goals

- Keep one repo for all machines
- Reuse shared modules across device types
- Keep host-specific differences small and explicit
- Keep the infrastructure repo aligned with the canonical `~/Workspace` workspace layout

## Structure

```text
flake.nix                        # flake-parts entrypoint (auto-discovers feature modules)
modules/core/                    # option definitions + auto-discovery
modules/features/nixos/*/        # NixOS feature modules (auto-registered)
modules/features/home/*/         # Home Manager feature modules (auto-registered)
modules/hosts/*.nix              # host composition (imports features directly)
modules/users/*.nix              # user-level composition
modules/packages/flake-module.nix# overlay, packages, apps, dev shell, formatter
modules/checks/flake-module.nix  # flake checks
pkgs/                            # locally maintained packages, exposed via overlay
hosts/                           # hardware configs and host-local data
```

Adding a new feature: create `modules/features/{nixos,home}/my-feature/module.nix` — it's auto-registered, no boilerplate needed.

### `hosts/`

Each host folder contains only machine-local files:

- `hardware-configuration.nix` for machine-specific hardware
- optional host-local files like `syncthing.nix`
- optional untracked `pi-gateway.private.nix`

Current hosts:

- `evo-nixos` - mini PC / desktop workstation (gaming + NVIDIA)
- `pad-nixos` - laptop
- `vps-nixos` - canonical VPS

### `modules/`

Features are auto-discovered from `modules/features/{nixos,home}/` — any directory containing a `module.nix` is registered automatically as `flake.nixosModules.<name>` or `flake.homeModules.<name>`.

Notable features:

- `common`, `desktop`, `laptop`
- `role-gaming`, `role-nvidia`
- `service-networkmanager`, `service-openssh`, `service-reaction`, `service-syncthing`
- `service-llama-cpp`, `service-pi-gateway`

Host definitions in `modules/hosts/` import features directly — no intermediate profile layer.

### `pkgs/`

Locally maintained package definitions.

- `pkgs/pi` builds the Pi binary under our control
- `pkgs/pi-gateway` is the generic transport gateway (Signal and WhatsApp)
- `pkgs/pi-web-access` provides the web-search extension
- `pkgs/llm-wiki` provides the wiki extension
- packages are exported through `overlays.default` and reused everywhere

### `service-pi-gateway`

The `modules/features/nixos/service-pi-gateway/` NixOS module manages the pi-gateway service.

It provides:
- `services.pi-gateway.enable`
- `services.pi-gateway.signal.*` — Signal transport config
- `services.pi-gateway.whatsapp.*` — WhatsApp transport config (Baileys-based)
- `services.pi-gateway.maxReplyChars` / `maxReplyChunks`
- runs as the primary user so it inherits pi auth credentials

Typical usage (e.g. in a host file):

```nix
services.pi-gateway = {
  enable = true;

  signal = {
    enable = true;
    account = "+15550001111";
    allowedNumbers = [ "+15550002222" ];
    adminNumbers = [ "+15550002222" ];
  };

  whatsapp = {
    enable = true;
    trustedNumbers = [ "+15550002222" ];
    adminNumbers = [ "+15550002222" ];
  };
};
```

The Signal transport requires `signal-cli-rest-api` running at `http://127.0.0.1:8080` (configurable).

The WhatsApp transport uses Baileys and persists auth state under the gateway state directory.

### Home Manager

Shared Home Manager config for `alex` is composed from dendritic home features.

- `modules/users/alex.nix` is the shared entrypoint
- `modules/features/home/*` splits user config by concern
- `modules/features/home/host-*` holds host-specific Home Manager additions
- `modules/features/home/pi/` holds Pi-specific user infrastructure

### Restored PI runtime capabilities

The Pi runtime includes several capabilities:

- `persona` extension — guardrails, persona layers, session context tracking
- `os` extension — `system_health`, `nixos_update`, `systemd_control`, `schedule_reboot`
- `sudo-auth` extension — intercepts sudo, tracks credentials, footer status
- `nixpi` extension — `nixpi_status`, `nixpi_evolution_note`, `/nixpi status`
- `subagent` extension — isolated helper agents (scout/planner/worker/reviewer)
- restored PI skills — `os-operations`, `self-evolution`, `provisioning`, `first-boot`

These runtime files are installed under `~/.pi/agent/` by Home Manager and validated by flake checks plus the dedicated `pi-runtime-smoke` VM test.

### Synthetic + local llama provider wiring

Pi seeds a Nix-managed `~/.pi/agent/models.json` for custom providers:

- `synthetic` — OpenAI-compatible, authenticated via `SYNTHETIC_API_KEY`
- `llama` — local llama.cpp endpoint on `evo-nixos`

Typical shell setup before launching `pi`:

```bash
export SYNTHETIC_API_KEY=your_synthetic_key
pi
```

### Privileged PI flows

PI stays unprivileged:

- read-only inspection tools run directly without sudo
- privileged mutations use `sudo -n` after ensuring credentials are available
- common operations have NOPASSWD sudoers rules
- `sudoers` uses `timestamp_type=global` so credentials propagate across sessions

### `evo-nixos` AI coding CLIs

`evo-nixos` integrates `github:numtide/llm-agents.nix` and installs `claude-code`, `codex`, `copilot-cli`. Bash wrappers unset API-key environment variables so OAuth takes precedence.

## NixPI helper command

```bash
nix run .#nixpi-vcp              # validate + commit + push
nix run .#nixpi-vcp -- "message" # with custom commit message
```

## Current conventions

### Shared user folders

- `~/Workspace`
- `~/Workspace/NixPI`
- `~/Workspace/Knowledge`
- `~/Workspace/Infrastructure`

### Syncing

Syncthing syncs `~/Workspace/Knowledge`. The infrastructure repo is synced via Git/GitHub.

## Rebuild

```bash
nh os switch   # evo-nixos (reads NH_FLAKE automatically)
sudo nixos-rebuild switch --flake ~/Workspace/NixPI#vps-nixos
sudo nixos-rebuild switch --flake ~/Workspace/NixPI#pad-nixos
```

## Quality checks

```bash
nix fmt                          # format all Nix files
nix flake check --accept-flake-config  # run all checks
```

### Current test coverage

- formatting for all Nix files
- `llm-wiki` unit tests
- host contract checks for `evo-nixos`, `pad-nixos`, `vps-nixos`
- host build contract checks
- gaming/NVIDIA contract checks
- VM smoke tests: `server-base`, `desktop-workstation`, `laptop-workstation`, `evo-nixos`, `pad-nixos`, `vps-nixos`, `pi-runtime`

Run individual smoke tests:

```bash
nix build .#checks.x86_64-linux.server-base-smoke -L
nix build .#checks.x86_64-linux.desktop-workstation-smoke -L
nix build .#checks.x86_64-linux.evo-nixos-smoke -L
```

## Notes

- `system.stateVersion` stays host-local
- shared user config lives in Home Manager
- machine-specific overrides should stay small and obvious
- repo-specific binary cache settings live in `flake.nix` via `nixConfig`
