#!/bin/bash
# Desktop kernel on the stable line: kernel.org 7.3 stable (versions.env STABLE_*) + the HDMI patches in
# ./patches (Tomi Valkeinen's tidss / AM62P display series on 7.3; patches/README.md),
# board DTS with display (board/dts/k3-am67a-t3-gem-o1-lts-hdmi.dts, also used by the 6.18 kernel).
# -> kernels/stable-hdmi/out/{linux-image-*-gemstone-stable-hdmi*.deb, Image, k3-am67a-t3-gem-o1.dtb, release}
# Usage: kernels/stable-hdmi/build.sh   (also PREP_ONLY=1, DTB_ONLY=1)
# Then:  ./build.sh desktop --kernel stable-hdmi
exec env TRACK=stable VARIANT=hdmi "$(cd "$(dirname "$0")/../mainline" && pwd)/build.sh" "$@"
