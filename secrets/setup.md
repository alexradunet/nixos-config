# sops-nix setup

## 1. Generate or choose recipients

Typical user key flow:

```bash
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt
grep '^# public key:' ~/.config/sops/age/keys.txt
```

Typical host-based flow from an SSH host public key:

```bash
ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub
```

You usually want:

- one personal recipient for yourself
- one recipient per host that should decrypt its own secrets

## 2. Add recipients to `secrets/.sops.yaml`

Use `secrets/recipients.example.yaml` as the template.

A practical pattern is:

- `common.yaml`: your user key + all hosts that need shared secrets
- `evo-nixos.yaml`: your user key + `evo-nixos`
- `pad-nixos.yaml`: your user key + `pad-nixos`
- `vps-nixos.yaml`: your user key + `vps-nixos`

## 3. Create encrypted files

Examples:

```bash
sops secrets/common.yaml
sops secrets/evo-nixos.yaml
sops secrets/pad-nixos.yaml
sops secrets/vps-nixos.yaml
```

## 4. Current example secret

If `secrets/common.yaml` contains:

```yaml
github:
  token: ghp_example
```

then NixOS will materialize it at:

```text
/run/secrets/github-token
```

owned by `alex:users` with mode `0400`.

Interactive zsh shells will also export:

- `GITHUB_TOKEN`
- `GH_TOKEN`

from that file when it exists.

## 5. Rebuild the target host

```bash
sudo nixos-rebuild switch --flake ~/nixos-config#evo-nixos
```

## Notes

- This repo auto-loads `secrets/<host>.yaml` only if the file exists.
- Shared secrets from `secrets/common.yaml` are also loaded when present.
- Common sops host integration is enabled through `modules/secrets/common.nix`.
- Current config uses `/etc/ssh/ssh_host_ed25519_key` as the default decryption identity on NixOS hosts.
