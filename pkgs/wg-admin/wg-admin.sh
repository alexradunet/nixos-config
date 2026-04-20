#!/usr/bin/env bash
set -euo pipefail

WG_ADMIN_HOME="${WG_ADMIN_HOME:-/var/lib/wg-admin}"
WG_ADMIN_ETC_CONFIG="${WG_ADMIN_ETC_CONFIG:-/etc/wg-admin/config.env}"
WG_ADMIN_IP_START="${WG_ADMIN_IP_START:-30}"

if [[ -f "$WG_ADMIN_ETC_CONFIG" ]]; then
  # shellcheck disable=SC1090,SC1091
  . "$WG_ADMIN_ETC_CONFIG"
fi

if [[ -f "$WG_ADMIN_HOME/config.env" ]]; then
  # shellcheck disable=SC1090,SC1091
  . "$WG_ADMIN_HOME/config.env"
fi

PEERS_DIR="${WG_ADMIN_PEERS_DIR:-$WG_ADMIN_HOME/peers}"
GENERATED_DIR="${WG_ADMIN_GENERATED_DIR:-$WG_ADMIN_HOME/generated}"
ARCHIVE_DIR="${WG_ADMIN_ARCHIVE_DIR:-$WG_ADMIN_HOME/archive}"
WG_ADMIN_SUBNET="${WG_ADMIN_SUBNET:-10.77.0.0/24}"
WG_ADMIN_ALLOWED_IPS="${WG_ADMIN_ALLOWED_IPS:-$WG_ADMIN_SUBNET}"
WG_ADMIN_PERSISTENT_KEEPALIVE="${WG_ADMIN_PERSISTENT_KEEPALIVE:-25}"
WG_ADMIN_INTERFACE="${WG_ADMIN_INTERFACE:-wg0}"
WG_ADMIN_NIX_PEERS_FILE="${WG_ADMIN_NIX_PEERS_FILE:-$WG_ADMIN_HOME/nix/peers.nix}"

ensure_state_dirs() {
  mkdir -p "$PEERS_DIR" "$GENERATED_DIR" "$ARCHIVE_DIR" "$(dirname "$WG_ADMIN_NIX_PEERS_FILE")"
  chmod 700 "$WG_ADMIN_HOME" "$PEERS_DIR" "$GENERATED_DIR" "$ARCHIVE_DIR" "$(dirname "$WG_ADMIN_NIX_PEERS_FILE")" 2>/dev/null || true
}

usage() {
  cat <<'EOF'
wg-admin - lightweight WireGuard peer registry and QR onboarding helper

Commands:
  list
  add <name> [ip]
  show <name>
  conf <name>
  qr <name> [--png]
  nix-snippet <name>
  enable <name>
  disable <name>
  sync-nix
  help

Config is loaded from:
  1. /etc/wg-admin/config.env
  2. $WG_ADMIN_HOME/config.env

Important:
  - This MVP keeps a runtime peer registry and generates client configs/QR codes.
  - It also regenerates a dedicated Nix peer inventory file for the hub when peers change.
  - Rebuild the hub after changes so WireGuard picks them up.
EOF
}

die() {
  echo "Error: $*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

require_runtime_config() {
  [[ -n "${WG_ADMIN_SERVER_PUBLIC_KEY:-}" ]] || die "WG_ADMIN_SERVER_PUBLIC_KEY is not set"
  [[ -n "${WG_ADMIN_SERVER_ENDPOINT:-}" ]] || die "WG_ADMIN_SERVER_ENDPOINT is not set"
}

normalize_name() {
  local name="$1"
  [[ "$name" =~ ^[a-zA-Z0-9._-]+$ ]] || die "Peer name must match [a-zA-Z0-9._-]+"
  printf '%s\n' "$name"
}

peer_file() {
  printf '%s/%s.env\n' "$PEERS_DIR" "$1"
}

conf_file() {
  printf '%s/%s.conf\n' "$GENERATED_DIR" "$1"
}

png_file() {
  printf '%s/%s.png\n' "$GENERATED_DIR" "$1"
}

now_iso() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

load_peer() {
  local file
  file="$(peer_file "$1")"
  [[ -f "$file" ]] || die "Peer not found: $1"

  unset NAME IP PUBLIC_KEY PRIVATE_KEY ENABLED CREATED_AT UPDATED_AT
  # shellcheck disable=SC1090,SC1091
  . "$file"
}

save_peer() {
  local peer_name="$1"
  local peer_ip="$2"
  local peer_public_key="$3"
  local peer_private_key="$4"
  local peer_enabled="$5"
  local peer_created_at="$6"
  local peer_updated_at="$7"
  local file tmp

  file="$(peer_file "$peer_name")"
  tmp="${file}.tmp"

  cat >"$tmp" <<EOF
NAME=$(printf '%q' "$peer_name")
IP=$(printf '%q' "$peer_ip")
PUBLIC_KEY=$(printf '%q' "$peer_public_key")
PRIVATE_KEY=$(printf '%q' "$peer_private_key")
ENABLED=$(printf '%q' "$peer_enabled")
CREATED_AT=$(printf '%q' "$peer_created_at")
UPDATED_AT=$(printf '%q' "$peer_updated_at")
EOF

  chmod 600 "$tmp"
  mv "$tmp" "$file"
}

render_conf() {
  local name="$1"
  load_peer "$name"
  require_runtime_config

  local dns_line mtu_line
  dns_line=""
  mtu_line=""

  if [[ -n "${WG_ADMIN_DNS:-}" ]]; then
    dns_line="DNS = ${WG_ADMIN_DNS}"
  fi

  if [[ -n "${WG_ADMIN_MTU:-}" ]]; then
    mtu_line="MTU = ${WG_ADMIN_MTU}"
  fi

  cat <<EOF
[Interface]
PrivateKey = ${PRIVATE_KEY}
Address = ${IP}/32
${dns_line}
${mtu_line}

[Peer]
PublicKey = ${WG_ADMIN_SERVER_PUBLIC_KEY}
Endpoint = ${WG_ADMIN_SERVER_ENDPOINT}
AllowedIPs = ${WG_ADMIN_ALLOWED_IPS}
PersistentKeepalive = ${WG_ADMIN_PERSISTENT_KEEPALIVE}
EOF
}

write_conf() {
  local name="$1"
  local file tmp
  file="$(conf_file "$name")"
  tmp="${file}.tmp"
  render_conf "$name" >"$tmp"
  chmod 600 "$tmp"
  mv "$tmp" "$file"
}

sync_nix_inventory() {
  local file tmp peer_env
  file="$WG_ADMIN_NIX_PEERS_FILE"
  tmp="${file}.tmp"

  {
    echo "["
    for peer_env in "$PEERS_DIR"/*.env; do
      [[ -e "$peer_env" ]] || continue
      unset NAME IP PUBLIC_KEY PRIVATE_KEY ENABLED CREATED_AT UPDATED_AT
      # shellcheck disable=SC1090,SC1091
      . "$peer_env"
      [[ "${ENABLED:-0}" == "1" ]] || continue
      # shellcheck disable=SC2153
      cat <<EOF
  {
    name = "${NAME}";
    publicKey = "${PUBLIC_KEY}";
    ip = "${IP}";
  }
EOF
    done
    echo "]"
  } >"$tmp"

  chmod 600 "$tmp"
  mv "$tmp" "$file"
}

existing_ip_in_use() {
  local candidate="$1"
  local file

  for file in "$PEERS_DIR"/*.env; do
    [[ -e "$file" ]] || continue
    unset IP
    # shellcheck disable=SC1090,SC1091
    . "$file"
    if [[ "${IP:-}" == "$candidate" ]]; then
      return 0
    fi
  done

  return 1
}

next_ip() {
  local subnet prefix host candidate
  subnet="$WG_ADMIN_SUBNET"

  [[ "$subnet" =~ ^([0-9]+\.[0-9]+\.[0-9]+)\.0/24$ ]] || die "Only IPv4 /24 subnets are supported right now (got: $subnet)"
  prefix="${BASH_REMATCH[1]}"

  for ((host = WG_ADMIN_IP_START; host <= 254; host++)); do
    candidate="${prefix}.${host}"
    if ! existing_ip_in_use "$candidate"; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  die "No free IPs left in ${subnet} starting from .${WG_ADMIN_IP_START}"
}

cmd_list() {
  local file first_line
  printf '%-24s %-15s %-8s %-20s\n' NAME IP ENABLED CREATED_AT
  printf '%-24s %-15s %-8s %-20s\n' '------------------------' '---------------' '--------' '--------------------'

  for file in "$PEERS_DIR"/*.env; do
    [[ -e "$file" ]] || continue
    unset NAME IP ENABLED CREATED_AT
    # shellcheck disable=SC1090,SC1091
    . "$file"
    printf '%-24s %-15s %-8s %-20s\n' "${NAME:-?}" "${IP:-?}" "${ENABLED:-?}" "${CREATED_AT:-?}"
    first_line=1
  done

  [[ -n "${first_line:-}" ]] || echo "(no peers yet)"
}

cmd_add() {
  local name ip peer_private_key peer_public_key created_at
  name="$(normalize_name "$1")"
  ip="${2:-}"

  require_cmd wg
  require_runtime_config
  [[ ! -f "$(peer_file "$name")" ]] || die "Peer already exists: $name"

  if [[ -z "$ip" ]]; then
    ip="$(next_ip)"
  fi

  [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "IP must be a plain IPv4 address without CIDR suffix"
  ! existing_ip_in_use "$ip" || die "IP already in use: $ip"

  peer_private_key="$(wg genkey)"
  peer_public_key="$(printf '%s' "$peer_private_key" | wg pubkey)"
  created_at="$(now_iso)"

  save_peer "$name" "$ip" "$peer_public_key" "$peer_private_key" "1" "$created_at" "$created_at"
  write_conf "$name"
  sync_nix_inventory

  cat <<EOF
Added peer: ${name}
IP: ${ip}
Config: $(conf_file "$name")
QR PNG: $(png_file "$name")
Nix peers file: ${WG_ADMIN_NIX_PEERS_FILE}

Nix snippet:
$(cmd_nix_snippet "$name")

Next step: rebuild vps-nixos so the hub picks up the regenerated peer inventory.
EOF
}

cmd_show() {
  local name
  name="$(normalize_name "$1")"
  load_peer "$name"

  cat <<EOF
Name: ${NAME}
IP: ${IP}
Enabled: ${ENABLED}
Created: ${CREATED_AT}
Updated: ${UPDATED_AT}
PublicKey: ${PUBLIC_KEY}
Config: $(conf_file "$name")
QR PNG: $(png_file "$name")
EOF
}

cmd_conf() {
  local name
  name="$(normalize_name "$1")"
  if [[ ! -f "$(conf_file "$name")" ]]; then
    write_conf "$name"
  fi
  cat "$(conf_file "$name")"
}

cmd_qr() {
  local name mode
  name="$(normalize_name "$1")"
  mode="${2:-terminal}"

  require_cmd qrencode

  if [[ ! -f "$(conf_file "$name")" ]]; then
    write_conf "$name"
  fi

  case "$mode" in
    terminal)
      qrencode -t ansiutf8 <"$(conf_file "$name")"
      ;;
    --png)
      qrencode -o "$(png_file "$name")" <"$(conf_file "$name")"
      chmod 600 "$(png_file "$name")"
      png_file "$name"
      ;;
    *)
      die "Unknown qr mode: $mode"
      ;;
  esac
}

cmd_nix_snippet() {
  local name
  name="$(normalize_name "$1")"
  load_peer "$name"

  cat <<EOF
{
  name = "${NAME}";
  publicKey = "${PUBLIC_KEY}";
  ip = "${IP}";
}
EOF
}

toggle_enabled() {
  local name enabled now
  name="$(normalize_name "$1")"
  enabled="$2"
  load_peer "$name"
  now="$(now_iso)"
  save_peer "$NAME" "$IP" "$PUBLIC_KEY" "$PRIVATE_KEY" "$enabled" "$CREATED_AT" "$now"
  sync_nix_inventory
  echo "${name}: ENABLED=${enabled}"
  echo "Nix peers file updated: ${WG_ADMIN_NIX_PEERS_FILE}"
}

main() {
  local cmd
  cmd="${1:-help}"

  case "$cmd" in
    list)
      ensure_state_dirs
      cmd_list
      ;;
    add)
      ensure_state_dirs
      [[ $# -ge 2 ]] || die "Usage: wg-admin add <name> [ip]"
      cmd_add "$2" "${3:-}"
      ;;
    show)
      ensure_state_dirs
      [[ $# -ge 2 ]] || die "Usage: wg-admin show <name>"
      cmd_show "$2"
      ;;
    conf)
      ensure_state_dirs
      [[ $# -ge 2 ]] || die "Usage: wg-admin conf <name>"
      cmd_conf "$2"
      ;;
    qr)
      ensure_state_dirs
      [[ $# -ge 2 ]] || die "Usage: wg-admin qr <name> [--png]"
      cmd_qr "$2" "${3:-terminal}"
      ;;
    nix-snippet)
      ensure_state_dirs
      [[ $# -ge 2 ]] || die "Usage: wg-admin nix-snippet <name>"
      cmd_nix_snippet "$2"
      ;;
    enable)
      ensure_state_dirs
      [[ $# -ge 2 ]] || die "Usage: wg-admin enable <name>"
      toggle_enabled "$2" "1"
      ;;
    disable)
      ensure_state_dirs
      [[ $# -ge 2 ]] || die "Usage: wg-admin disable <name>"
      toggle_enabled "$2" "0"
      ;;
    sync-nix)
      ensure_state_dirs
      sync_nix_inventory
      echo "$WG_ADMIN_NIX_PEERS_FILE"
      ;;
    help|-h|--help)
      usage
      ;;
    *)
      die "Unknown command: $cmd"
      ;;
  esac
}

main "$@"
