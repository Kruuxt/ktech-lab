#!/usr/bin/env bash
# pull-configs.sh — role-aware pull without nested filename folders

set -uo pipefail

DEST="/home/kruuxt/DevProjects/KTech-Lab/ktech-lab/configs"
OPN_HOST="192.168.10.1"  # OPNsense (FreeBSD)
OPN_PORT="22"
PROX_HOST="192.168.10.2" # Proxmox (Linux)
PROX_PORT="22"
DATE="$(date +%F)"

# Reasonable, quiet SSH/SCP defaults; still prompts for password.
SSH_OPTS='-o ConnectTimeout=6 -o ConnectionAttempts=1 -o PreferredAuthentications=password -o PubkeyAuthentication=no -o GSSAPIAuthentication=no'
SCP_OPTS='-O -o ConnectTimeout=6 -o PreferredAuthentications=password -o PubkeyAuthentication=no -o GSSAPIAuthentication=no'

# Relaunch in a terminal if double-clicked (so prompts are visible)
if [[ ! -t 1 ]]; then
  if command -v konsole >/dev/null 2>&1; then exec konsole -e bash -lc "bash '$0'"; fi
  if command -v gnome-terminal >/dev/null 2>&1; then exec gnome-terminal -- bash -lc "bash '$0'"; fi
  if command -v xterm >/dev/null 2>&1; then exec xterm -e bash -lc "bash '$0'"; fi
fi

echo "== Homelab config pull =="
echo "Destination: $DEST"

# --- helpers ---
# Copy to an EXACT file path: makes only the parent dir; no nested filename/filename
pull_exact() { # pull_exact <user@host> <port> <remote_path> <local_file_exact>
  local userhost="$1" port="$2" r="$3" lf="$4"
  mkdir -p "$(dirname "$lf")"
  # Quote remote so globs are remote-side (if present) but here we expect a file
  if ! scp $SCP_OPTS -P "$port" ${userhost}:"$r" "$lf"; then
    echo "[warn] could not copy ${userhost}:$r → $lf"
  fi
}

# Copy one or many files into a destination DIRECTORY (used for globs)
pull_into_dir() { # pull_into_dir <user@host> <port> <remote_glob> <local_dir>
  local userhost="$1" port="$2" rg="$3" ld="$4"
  mkdir -p "$ld"
  if ! scp $SCP_OPTS -P "$port" ${userhost}:"$rg" "$ld"/ 2>/dev/null; then
    echo "[warn] could not copy ${userhost}:$rg → $ld/"
  fi
}

probe_os() { # probe_os <user@host> <port>
  ssh $SSH_OPTS -p "$2" "$1" uname -s 2>/dev/null || echo "UNKNOWN"
}

# --- make base dirs you truly want as directories ---
mkdir -p \
  "$DEST/proxmox/qemu" \
  "$DEST/proxmox/modprobe.d" \
  "$DEST/proxmox/firewall" \
  "$DEST/opnsense/backup"

# ---------------- OPNsense (FreeBSD) ----------------
echo
echo "[*] Pulling from OPNsense ($OPN_HOST)"
OPN_USERHOST="root@${OPN_HOST}"
OPN_UNAME=$(probe_os "$OPN_USERHOST" "$OPN_PORT")
[[ "$OPN_UNAME" != "FreeBSD" ]] && echo "[warn] $OPN_HOST reported '$OPN_UNAME' (expected FreeBSD). Continuing…"

# Exact file target (no nested dirs)
pull_exact "$OPN_USERHOST" "$OPN_PORT" "/conf/config.xml" "$DEST/opnsense/backup/config.xml"

# ---------------- Proxmox (Linux) ----------------
echo
echo "[*] Pulling from Proxmox ($PROX_HOST)"
PROX_USERHOST="root@${PROX_HOST}"
PROX_UNAME=$(probe_os "$PROX_USERHOST" "$PROX_PORT")
[[ "$PROX_UNAME" != "Linux" ]] && echo "[warn] $PROX_HOST reported '$PROX_UNAME' (expected Linux). Continuing…"

# Cluster-wide configs — exact file placement
pull_exact "$PROX_USERHOST" "$PROX_PORT" "/etc/pve/datacenter.cfg"     "$DEST/proxmox/datacenter.cfg"
pull_exact "$PROX_USERHOST" "$PROX_PORT" "/etc/pve/storage.cfg"        "$DEST/proxmox/storage.cfg"
pull_exact "$PROX_USERHOST" "$PROX_PORT" "/etc/pve/user.cfg"           "$DEST/proxmox/user.cfg"

# VM definitions (glob → directory)
pull_into_dir "$PROX_USERHOST" "$PROX_PORT" "/etc/pve/qemu-server/*.conf" "$DEST/proxmox/qemu"

# Host identity — exact files
pull_exact "$PROX_USERHOST" "$PROX_PORT" "/etc/hostname"                "$DEST/proxmox/hostname"
pull_exact "$PROX_USERHOST" "$PROX_PORT" "/etc/hosts"                   "$DEST/proxmox/hosts"

# Networking — exact file
pull_exact "$PROX_USERHOST" "$PROX_PORT" "/etc/network/interfaces"      "$DEST/proxmox/network.interfaces"

# Backup policy — exact file
pull_exact "$PROX_USERHOST" "$PROX_PORT" "/etc/vzdump.conf"             "$DEST/proxmox/vzdump.conf"

# Boot/kernel + modules — exact files, plus a glob into a directory
pull_exact "$PROX_USERHOST" "$PROX_PORT" "/etc/default/grub"            "$DEST/proxmox/grub"
pull_exact "$PROX_USERHOST" "$PROX_PORT" "/etc/modules"                 "$DEST/proxmox/modules"
pull_into_dir "$PROX_USERHOST" "$PROX_PORT" "/etc/modprobe.d/*.conf"    "$DEST/proxmox/modprobe.d"

# Tighten local permissions
chmod -R go-rwx "$DEST" || true

# snapshot the current tree for audit trails
SNAP="/file-list/file-list-$(date +%Y%m%d_%H%M%S).txt"
( cd "$DEST" && find . -print | sort ) > "$DEST/$SNAP"
echo "[ok] Wrote snapshot: $DEST/$SNAP"

cat <<'EON'

[!] Review & sanitize before commit:
    - Proxmox: storage.cfg may contain NFS/SMB creds, public IPs/FQDNs.
    - OPNsense: config.xml contains secrets (VPN keys, PPPoE creds, API tokens).
    - Keep private RFC1918 (192.168.x.x); hide public IPs/DDNS.
EON

read -r _
