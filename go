#!/bin/bash
# Short cut for the Debian 13 image step alone (03), with a log.  Usage: sudo ./go [options of go-pardus]
cd "$(dirname "$0")" && ./scripts/03-rootfs-image.sh --distro debian "$@" 2>&1 | tee out-rootfs.log
