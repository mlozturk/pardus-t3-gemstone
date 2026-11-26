#!/bin/bash
# Debian trixie 6.12 kernel + display/GPU drivers from 6.18 + HDMI patches (desktop). See kernels/trixie/build.sh.
exec env VARIANT=hdmi "$(cd "$(dirname "$0")/.." && pwd)/trixie/build.sh" "$@"
