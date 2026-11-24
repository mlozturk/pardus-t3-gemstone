#!/bin/bash
# Headless kernel on the stable line: kernel.org 7.3 stable (versions.env STABLE_*), NOT patched,
# same small config and board DTS as kernels/mainline (6.18 LTS).
# -> kernels/stable/out/{linux-image-*-gemstone-stable*.deb, Image, k3-am67a-t3-gem-o1.dtb, release}
# Usage: kernels/stable/build.sh   (also PREP_ONLY=1, DTB_ONLY=1; see kernels/mainline/build.sh)
# Then:  ./build.sh headless --kernel stable
# 7.3 is not a longterm kernel: kernel.org ends it a few weeks after 7.4 is released.
exec env TRACK=stable VARIANT=plain "$(cd "$(dirname "$0")/../mainline" && pwd)/build.sh" "$@"
