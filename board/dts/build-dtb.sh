#!/bin/bash
# Compile a board DTS from this folder against a kernel tree's SoC .dtsi files, without copying
# anything into that tree. Used by kernels/debian/build.sh and kernels/mainline/build.sh.
#
# Usage: board/dts/build-dtb.sh <kernel-source-dir> <dts-name> <out.dtb> [dtc]
#   e.g. board/dts/build-dtb.sh kernels/mainline/src k3-am67a-t3-gem-o1-headless.dts out.dtb
#   dtc: the kernel's own (<build>/scripts/dtc/dtc) if given, else the host's dtc
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
KSRC=$(cd "${1:?kernel source dir}" && pwd)
DTS=${2:?dts name}
OUTF=${3:?output .dtb}
DTC=${4:-dtc}
[ -f "$HERE/$DTS" ] || { echo "no $DTS in $HERE"; exit 1; }
PP=$(mktemp --suffix=.dts)
trap 'rm -f "$PP"' EXIT
# this folder first: our pinmux .dtsi wins over a copy of the same name inside the kernel tree
cpp -nostdinc -I "$HERE" -I "$KSRC/include" -I "$KSRC/arch/arm64/boot/dts" -I "$KSRC/arch/arm64/boot/dts/ti" \
    -undef -D__DTS__ -x assembler-with-cpp "$HERE/$DTS" > "$PP"
"$DTC" -q -I dts -O dtb -@ -o "$OUTF" "$PP"
echo "dtb: $DTS -> $OUTF"
