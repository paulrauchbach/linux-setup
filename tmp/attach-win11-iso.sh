#!/usr/bin/env bash
set -euo pipefail

vm_name="${VM_NAME:-win11-stripped}"
iso_path="${1:-}"

if [[ -z "$iso_path" ]]; then
  iso_path="$(find /home/paul/Downloads -maxdepth 1 -type f \
    \( -iname 'Win11*.iso' -o -iname '*Windows*11*.iso' \) \
    -printf '%T@ %p\n' | sort -nr | awk 'NR == 1 {print substr($0, index($0,$2))}')"
fi

if [[ -z "$iso_path" || ! -f "$iso_path" ]]; then
  echo "Usage: $0 /path/to/Win11.iso" >&2
  echo "No Windows 11 ISO found in /home/paul/Downloads." >&2
  exit 1
fi

virsh --connect qemu:///system change-media "$vm_name" sda "$iso_path" \
  --insert --config

echo "Attached installer ISO to $vm_name: $iso_path"
echo "Open virt-manager, start $vm_name, and load storage drivers from the VirtIO CD-ROM if Windows setup cannot see the disk."
