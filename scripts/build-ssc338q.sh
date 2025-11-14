#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
PROJECT_ROOT="${SCRIPT_DIR%/*}"

TOOLCHAIN_ROOT=${TOOLCHAIN_ROOT:-$HOME/builder/openipc/toolchain-ssc338q_gcc-12.2.0_glibc}
KERNEL_DIR=${KERNEL_DIR:-$HOME/builder/openipc/kernel-ssc338q}
CROSS_COMPILE=${CROSS_COMPILE:-${TOOLCHAIN_ROOT}/bin/arm-openipc-linux-gnueabihf-}
MAKE_JOBS=${MAKE_JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)}

export ARCH=arm
export CROSS_COMPILE

if [ ! -d "$KERNEL_DIR" ]; then
    echo "Kernel directory '$KERNEL_DIR' not found" >&2
    exit 1
fi

if [ ! -x "${CROSS_COMPILE}gcc" ]; then
    echo "Cross-compiler '${CROSS_COMPILE}gcc' not found" >&2
    exit 1
fi

exec ${MAKE:-make} -C "$PROJECT_ROOT" \
    KSRC="$KERNEL_DIR" \
    CONFIG_AP_MODE=y \
    -j"$MAKE_JOBS" \
    modules
