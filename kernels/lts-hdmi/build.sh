#!/bin/bash
# Desktop kernel on the LTS line: kernel.org 6.18 LTS (versions.env MAINLINE_*) + the HDMI patches in
# ./patches (Tomi Valkeinen's tidss / AM62P display series, ported to 6.18; patches/README.md),
# board DTS with display (board/dts/k3-am67a-t3-gem-o1-lts-hdmi.dts).
# -> kernels/lts-hdmi/out/{linux-image-*-gemstone-hdmi*.deb, Image, k3-am67a-t3-gem-o1.dtb, release}
# Usage: kernels/lts-hdmi/build.sh   (also PREP_ONLY=1, DTB_ONLY=1; see kernels/mainline/build.sh)
# Then:  ./build.sh image --flavor lite --kernel lts-hdmi
exec env TRACK=lts VARIANT=hdmi "$(cd "$(dirname "$0")/../mainline" && pwd)/build.sh" "$@"
