#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib.sh"

DEVICE="${1:-${FOXFLOW_DATA_DEVICE:-/dev/disk/azure/scsi1/lun0}}"
MOUNT_POINT="${FOXFLOW_DATA_PATH:-/srv/foxflow}"

if [[ ! -b "$DEVICE" ]]; then
  log_error "Data disk not found at $DEVICE"
  log_error "Run 'lsblk -f' and pass the correct device as the first argument."
  exit 1
fi

REAL_DEVICE="$(readlink -f "$DEVICE")"
CURRENT_MOUNT="$(findmnt -rn -S "$REAL_DEVICE" -o TARGET 2>/dev/null || true)"
if [[ -n "$CURRENT_MOUNT" && "$CURRENT_MOUNT" != "$MOUNT_POINT" ]]; then
  log_error "$REAL_DEVICE is already mounted at $CURRENT_MOUNT; refusing to change it."
  exit 1
fi

FILESYSTEM="$(lsblk -no FSTYPE "$REAL_DEVICE" | head -n1)"
if [[ -z "$FILESYSTEM" ]]; then
  if lsblk -n -o TYPE "$REAL_DEVICE" | tail -n +2 | grep -q '^part$'; then
    log_error "$REAL_DEVICE contains partitions; pass the intended partition instead."
    exit 1
  fi
  log_info "Creating ext4 filesystem on new data disk $REAL_DEVICE..."
  sudo mkfs.ext4 -F "$REAL_DEVICE"
elif [[ "$FILESYSTEM" != "ext4" ]]; then
  log_error "$REAL_DEVICE uses $FILESYSTEM; expected ext4. Refusing to reformat it."
  exit 1
fi

sudo install -d -m 0755 "$MOUNT_POINT"
UUID="$(sudo blkid -s UUID -o value "$REAL_DEVICE")"
FSTAB_LINE="UUID=$UUID $MOUNT_POINT ext4 defaults,nofail 0 2"

if ! grep -Eq "^[^#]+[[:space:]]+$MOUNT_POINT[[:space:]]" /etc/fstab; then
  echo "$FSTAB_LINE" | sudo tee -a /etc/fstab >/dev/null
fi

if ! mountpoint -q "$MOUNT_POINT"; then
  sudo mount "$MOUNT_POINT"
fi

sudo install -d -m 0755 \
  "$MOUNT_POINT/config" \
  "$MOUNT_POINT/logs" \
  "$MOUNT_POINT/data"
sudo chown -R "${SUDO_USER:-$USER}:${SUDO_USER:-$USER}" "$MOUNT_POINT"

log_info "Data disk mounted at $MOUNT_POINT and persisted in /etc/fstab."
findmnt "$MOUNT_POINT"
