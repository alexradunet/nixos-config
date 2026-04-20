# modules/secrets

Shared `sops-nix` integration for this repo.

Exports:

- `nixosModules.sops` - upstream sops-nix module
- `nixosModules.sops-common` - shared host decryption defaults
- `nixosModules.sops-shared-common` - optional common secret declarations from `secrets/common.yaml`
- `nixosModules.sops-evo-nixos` - optional host-specific secret file loader
- `nixosModules.sops-pad-nixos` - optional host-specific secret file loader
- `nixosModules.sops-vps-nixos` - optional host-specific secret file loader
- `homeModules.sops` - upstream Home Manager sops module

Example shared secret path:

- `github.token` in `secrets/common.yaml`
- materialized at `/run/secrets/github-token`
- owned by `alex:users` with mode `0400`
