#!/bin/bash
# Collect finished images into a release folder: release/<version>/ with the .img.xz files,
# SHA256SUMS, the release notes and BUILDINFO.txt (git commit, pinned versions, image sums).
# Usage:  scripts/06-release.sh <version> [image.img.xz ...]
#   e.g.  scripts/06-release.sh 2026.11
#   without images: the newest desktop (lite, 6.18 LTS + HDMI) and headless (minimal, 6.18 LTS) images in out/
#         scripts/06-release.sh 2026.11-7.3 out/*-lite-*-kstable-hdmi.img.xz out/*-minimal-*-kstable.img.xz   (7.3)
# Files are hard links to out/ when possible (no extra disk space). No root needed.
set -euo pipefail
TOP=${TOP:-$(cd "$(dirname "$0")/.." && pwd)}
VER=${1:?usage: $0 <version> [image.img.xz ...]}; shift
case "$VER" in *[!A-Za-z0-9._-]*) echo "version: letters, digits, . _ - only"; exit 1 ;; esac
IMGS=("$@")
if [ ${#IMGS[@]} -eq 0 ]; then
  for pat in '-lite-*-klts-hdmi.img.xz' '-minimal-*-kmainline.img.xz'; do
    f=$(ls -t "$TOP"/out/t3-gem-o1-pardus-*$pat 2>/dev/null | head -1 || true)
    [ -n "$f" ] && IMGS+=("$f") || echo "warning: no out/*$pat"
  done
fi
[ ${#IMGS[@]} -gt 0 ] || { echo "no images"; exit 1; }
R=$TOP/release/$VER
mkdir -p "$R"
for f in "${IMGS[@]}"; do
  [ -f "$f" ] || { echo "missing: $f"; exit 1; }
  case "$f" in *.img.xz) ;; *) echo "not an .img.xz: $f"; exit 1 ;; esac
  sums=${f%.xz}.sha256
  [ -f "$sums" ] || { echo "missing checksum file: $sums"; exit 1; }
  # the .xz must still match what the image build wrote
  ( cd "$(dirname "$f")" && awk -v n="$(basename "$f")" '$2==n' "$(basename "$sums")" | sha256sum -c --quiet - ) \
    || { echo "checksum mismatch: $f"; exit 1; }
  ln -f "$f" "$R/" 2>/dev/null || cp -f "$f" "$R/"
  cp -f "$sums" "$R/"
  echo "added $(basename "$f")"
done
( cd "$R" && sha256sum ./*.img.xz | sed 's#  \./#  #' > SHA256SUMS )
# release notes: docs/SURUM-NOTLARI-<version>.md if there is one (e.g. 2026.11-7.3), else the main one
NOTES=$TOP/docs/SURUM-NOTLARI-$VER.md; [ -f "$NOTES" ] || NOTES=$TOP/docs/SURUM-NOTLARI.md
cp -f "$NOTES" "$R/SURUM-NOTLARI.md"
{
  echo "T3 Gemstone O1 / Pardus 25 release $VER, collected $(date -u +%Y-%m-%dT%H:%MZ)"
  echo "git: $(git -C "$TOP" rev-parse --short HEAD 2>/dev/null || echo none)$(git -C "$TOP" diff --quiet HEAD -- 2>/dev/null || echo ' (uncommitted changes)')"
  echo
  echo "== images (sha256 of .img and .img.xz)"
  cat "$R"/*.img.sha256
  echo
  echo "== pinned versions (versions.env)"
  grep -E '^[A-Z_]+=' "$TOP/versions.env" | grep -v PINNED
} > "$R/BUILDINFO.txt"
ls -la "$R"
echo "RELEASE_OK $R"
