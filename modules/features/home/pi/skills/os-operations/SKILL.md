---
name: os-operations
description: Inspect, manage, and remediate the NixPI system — NixOS rebuilds, service health, and targeted recovery
---

# OS Operations Skill

Use this skill when the user asks about host health, service state, rebuilds, or operational remediation.

## Use Tools First

Prefer extension tools over ad-hoc shell commands:

- `system_health` — broad health snapshot
- `nixos_update` — generations, declarative rebuilds, rollback
- `systemd_control` — safe service inspection and limited remediation

## Standard Triage Flow

1. Run `system_health`
2. If an OS issue is suspected: run `nixos_update(action="status")`
3. If a service issue is suspected: run `systemd_control action=status`
4. Apply the smallest safe remediation only with user approval
5. Re-run `system_health` to confirm recovery

## Healthy Signals

- `sshd.service` active/running
- `syncthing.service` active/running when expected
- `reaction.service` active/running on exposed hosts
- `nixos_update(action="status")` shows a current generation

## Safety Rules

- Mutating operations require explicit user approval
- Prefer declarative rebuilds over imperative drift
- Re-check health after every mutation
- Keep responses short and operational
