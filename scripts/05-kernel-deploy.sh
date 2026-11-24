#!/bin/bash
# Put a newly built kernel (Debian or mainline) on a running board over SSH (no SD card rewrite).
#
# Usage:  scripts/05-kernel-deploy.sh <board-ip> [ssh-key]
#   e.g.  scripts/05-kernel-deploy.sh 10.42.0.12 ~/.ssh/gemstone_board
#         KERNEL=mainline scripts/05-kernel-deploy.sh 10.42.0.12
#   KERNEL = lts-hdmi | mainline | stable-hdmi | stable | debian (default: the .kernel marker, else lts-hdmi)
#
# Steps: copy kernels/$KERNEL/out/{linux-image-*.deb, k3-am67a-t3-gem-o1.dtb} to ~pardus/gemstone-update/
#        -> board runs /usr/local/sbin/gemstone-kernel-update (installs the .deb, copies kernel,
#           initramfs and DTB to BOOT, keeps the old ones in /var/backups/gemstone-boot)
#        -> reboot -> wait -> save this boot's kernel log to kernels/$KERNEL/dmesg-<date>.txt
#
# One-time board setup (as root on the board, see docs/BELGE.md §22.3):
#   install -o root -g root -m 755 gemstone-kernel-update /usr/local/sbin/
#   echo 'pardus ALL=(root) NOPASSWD: /usr/local/sbin/gemstone-kernel-update, /usr/sbin/reboot' \
#        > /etc/sudoers.d/gemstone-kernel-update; chmod 440 /etc/sudoers.d/gemstone-kernel-update
#   and the build machine's public key in ~pardus/.ssh/authorized_keys
set -euo pipefail
TOP=${TOP:-$(cd "$(dirname "$0")/.." && pwd)}
IP=${1:?usage: $0 <board-ip> [ssh-key]}
KEY=${2:-$HOME/.ssh/gemstone_board}
KERNEL=${KERNEL:-$(cat "$TOP/.kernel" 2>/dev/null || echo lts-hdmi)}
case "$KERNEL" in debian|mainline|lts-hdmi|stable|stable-hdmi) ;; *) echo "KERNEL must be lts-hdmi, mainline, stable-hdmi, stable or debian (T3's kernel: write the SD card)"; exit 1 ;; esac
OUTD=$TOP/kernels/$KERNEL/out
ls "$OUTD"/linux-image-*.deb >/dev/null 2>&1 || { echo "no kernel package in $OUTD: run kernels/$KERNEL/build.sh"; exit 1; }
SSH=(ssh -i "$KEY" -o BatchMode=yes -o ConnectTimeout=8)
B=pardus@$IP

DEB=$(ls -t "$OUTD"/linux-image-*.deb | head -1)
echo "### sending $(basename "$DEB")"
"${SSH[@]}" "$B" "mkdir -p ~/gemstone-update && rm -f ~/gemstone-update/*"
scp -i "$KEY" -o BatchMode=yes "$DEB" "$OUTD/k3-am67a-t3-gem-o1.dtb" "$B:gemstone-update/"

echo "### installing on the board"
"${SSH[@]}" "$B" "sudo -n /usr/local/sbin/gemstone-kernel-update"

echo "### rebooting"
"${SSH[@]}" "$B" "sudo -n /usr/sbin/reboot" || true
sleep 25
for i in $(seq 30); do "${SSH[@]}" "$B" true 2>/dev/null && break; sleep 10; done
"${SSH[@]}" "$B" true || { echo "board did not come back; see docs/BELGE.md §22.6"; exit 2; }
sleep 30   # let late drivers settle
LOG=$TOP/kernels/$KERNEL/dmesg-$(date +%Y%m%d-%H%M).txt
"${SSH[@]}" "$B" "uname -rv; journalctl -k -b --no-pager -o short-monotonic" > "$LOG"
echo "### board is back: $(head -1 "$LOG")"
echo "### kernel log: $LOG ($(wc -l < "$LOG") lines)"
grep -iE 'oops|error|fail|warn' "$LOG" | head -20 || true
