# Secrets

This directory is reserved for encrypted secrets managed with `sops-nix`.

Suggested layout:

- `common.yaml`
- `evo-nixos.yaml`
- `pad-nixos.yaml`
- `vps-nixos.yaml`

After you generate age recipients, update `secrets/.sops.yaml` and create the encrypted files with `sops`.
