#!/bin/bash
# Write a T3 Gemstone O1 image to an SD card and verify it.
# Usage: sudo ./scripts/04-flash-sd.sh /dev/sdX [image | name-part] [--no-verify]
#   image      a .img or .img.xz file (.img.xz is decompressed on the fly, no 8 GB copy needed)
#   name-part  e.g. "minimal" or "lite-20261118": the newest image in out/ whose name contains it
#   (none)     the newest image in out/ (the name is printed before anything is written)
#   --no-verify  skip reading the card back (faster; only for quick test cards)
# Safety: only USB/MMC removable disks <= 256 GB are accepted, never the disk holding /.
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "run with sudo"; exit 1; }
TOP=${TOP:-$(cd "$(dirname "$0")/.." && pwd)}
DEV= ; SEL= ; VERIFY=1
for a in "$@"; do
  case "$a" in
    --no-verify) VERIFY=0 ;;
    /dev/*) DEV=$a ;;
    *) SEL=$a ;;
  esac
done
[ -n "$DEV" ] || { echo "usage: $0 /dev/sdX [image | name-part] [--no-verify]"; exit 1; }
if [ -n "$SEL" ] && [ -f "$SEL" ]; then
  IMG=$SEL
else
  # newest .img or .img.xz in out/ (matching SEL if given); for the same image prefer the .img
  IMG=$(ls -t "$TOP"/out/t3-gem-o1-*-arm64-*.img "$TOP"/out/t3-gem-o1-*-arm64-*.img.xz 2>/dev/null \
        | grep -F -- "${SEL:-t3-gem-o1-}" | head -1 || true)
  [ -n "$IMG" ] && [ "${IMG%.xz}" != "$IMG" ] && [ -f "${IMG%.xz}" ] && IMG=${IMG%.xz}
fi
[ -n "${IMG:-}" ] && [ -f "$IMG" ] || { echo "no image found (${SEL:-newest} in $TOP/out)"; exit 1; }
case "$IMG" in
  *.img.xz) XZ=1; n=$(xz --robot -l "$IMG" | awk '$1=="totals" {print $5}') ;;
  *.img)    XZ=0; n=$(stat -c %s "$IMG") ;;
  *) echo "not an .img / .img.xz: $IMG"; exit 1 ;;
esac
[ -n "$n" ] && [ "$n" -gt 0 ] || { echo "cannot read the image size of $IMG"; exit 1; }
# with a .sha256 next to it, check the file before writing it
SUMS=${IMG%.xz}.sha256
if [ -f "$SUMS" ]; then
  ( cd "$(dirname "$IMG")" && awk -v f="$(basename "$IMG")" '$2==f' "$(basename "$SUMS")" | grep -q . \
      && awk -v f="$(basename "$IMG")" '$2==f' "$(basename "$SUMS")" | sha256sum -c --quiet - ) \
    || { echo "checksum of $IMG does not match $SUMS"; exit 1; }
  echo "checksum OK ($SUMS)"
fi

[ -b "$DEV" ] || { echo "$DEV is not a block device"; exit 1; }
name=$(basename "$DEV")
tran=$(lsblk -dno TRAN "$DEV" || true)
rm=$(cat /sys/block/$name/removable 2>/dev/null || echo 0)
size=$(blockdev --getsize64 "$DEV")
rootdisk=$(lsblk -no PKNAME "$(findmnt -no SOURCE /)")
[ "$name" != "$rootdisk" ] || { echo "refusing: $DEV holds the root filesystem"; exit 1; }
case "$tran" in usb|mmc) ;; *) [ "$rm" = 1 ] || { echo "refusing: $DEV is not USB/MMC/removable (tran=$tran)"; exit 1; };; esac
[ "$size" -le $((256*1024*1024*1024)) ] || { echo "refusing: $DEV larger than 256 GB"; exit 1; }
[ "$size" -ge "$n" ] || { echo "refusing: $DEV smaller than the image ($n bytes)"; exit 1; }

echo "Image : $IMG ($((n/1024/1024)) MiB written)"
echo "Target: $DEV  $(lsblk -dno SIZE,MODEL "$DEV")"
lsblk "$DEV"

for p in $(lsblk -lnpo NAME "$DEV" | tail -n +2); do umount "$p" 2>/dev/null || true; done
echo "### writing"
if [ "$XZ" = 1 ]; then
  xz -dc "$IMG" | dd of="$DEV" bs=4M iflag=fullblock conv=fsync status=progress
else
  dd if="$IMG" of="$DEV" bs=4M conv=fsync status=progress
fi
sync
if [ "$VERIFY" = 0 ]; then
  echo "### verify skipped (--no-verify)"
else
  echo "### verifying"
  if [ "$XZ" = 1 ]; then a=$(xz -dc "$IMG" | sha256sum | cut -d' ' -f1); else a=$(sha256sum < "$IMG" | cut -d' ' -f1); fi
  b=$(head -c "$n" "$DEV" | sha256sum | cut -d' ' -f1)
  [ "$a" = "$b" ] && echo "VERIFY_OK $a" || { echo "VERIFY_FAILED image=$a card=$b"; exit 1; }
fi
partprobe "$DEV" 2>/dev/null || true
lsblk -o NAME,SIZE,FSTYPE,LABEL "$DEV"
echo FLASH_OK
