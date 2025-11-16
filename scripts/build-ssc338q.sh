#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
PROJECT_ROOT="${SCRIPT_DIR%/*}"

# Root folder containing OpenIPC toolchain and kernel
OPENIPC_ROOT=${OPENIPC_ROOT:-"$HOME/builder/openipc"}
# If default OPENIPC_ROOT doesn't exist, probe common alternates
if [ ! -d "$OPENIPC_ROOT" ]; then
    for base in /home/*/builder/openipc /opt/openipc; do
        if [ -d "$base" ]; then
            OPENIPC_ROOT="$base"
            break
        fi
    done
fi

# Allow overrides via env; otherwise try to auto-detect under OPENIPC_ROOT
TOOLCHAIN_ROOT=${TOOLCHAIN_ROOT:-}
KERNEL_DIR=${KERNEL_DIR:-}
MAKE_JOBS=${MAKE_JOBS:-$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)}

# Probe for a toolchain directory if not provided
if [ -z "${TOOLCHAIN_ROOT}" ]; then
    for d in \
        "$OPENIPC_ROOT"/output/host \
        "$OPENIPC_ROOT"/output/host/opt/ext-toolchain \
        "$OPENIPC_ROOT"/toolchain-ssc338q_* \
        "$OPENIPC_ROOT"/toolchain-ssc338q* \
        "$OPENIPC_ROOT"/toolchain* \
        "$OPENIPC_ROOT"/*toolchain* ; do
        if [ -d "$d/bin" ]; then
            TOOLCHAIN_ROOT="$d"
            break
        fi
    done
fi

if [ -z "${TOOLCHAIN_ROOT}" ] || [ ! -d "$TOOLCHAIN_ROOT/bin" ]; then
    echo "Toolchain not found under '$OPENIPC_ROOT'. Set TOOLCHAIN_ROOT to the toolchain directory." >&2
    exit 1
fi

# Derive CROSS_COMPILE if not already set; prefer musl then glibc
if [ -n "${CROSS_COMPILE:-}" ]; then
    CROSS_PREFIX="$CROSS_COMPILE"
else
    CROSS_PREFIX=""
    for triplet in arm-openipc-linux-musleabihf- arm-openipc-linux-gnueabihf- ; do
        if [ -x "$TOOLCHAIN_ROOT/bin/${triplet}gcc" ]; then
            CROSS_PREFIX="$TOOLCHAIN_ROOT/bin/$triplet"
            break
        fi
    done
    # Fallback: first *-gcc found
    if [ -z "$CROSS_PREFIX" ]; then
        for cc in "$TOOLCHAIN_ROOT"/bin/*-gcc ; do
            [ -x "$cc" ] || continue
            CROSS_PREFIX=${cc%gcc}
            break
        done
    fi
fi

if [ -z "$CROSS_PREFIX" ] || [ ! -x "${CROSS_PREFIX}gcc" ]; then
    echo "Cross-compiler '${CROSS_PREFIX}gcc' not found in '$TOOLCHAIN_ROOT/bin'." >&2
    exit 1
fi

export ARCH=arm
export CROSS_COMPILE="$CROSS_PREFIX"

# Locate kernel directory if not provided
if [ -z "${KERNEL_DIR}" ]; then
    for kd in \
        "$OPENIPC_ROOT"/output/build/linux-custom \
        "$OPENIPC_ROOT"/output/build/linux-* \
        "$OPENIPC_ROOT"/kernel-ssc338q \
        "$OPENIPC_ROOT"/linux-ssc338q \
        "$OPENIPC_ROOT"/kernel \
        "$OPENIPC_ROOT"/linux ; do
        if [ -d "$kd" ]; then
            # Prefer a tree with Module.symvers for external module builds
            if [ -f "$kd/Module.symvers" ] || [ -f "$kd/include/generated/autoconf.h" ] || [ -f "$kd/.config" ]; then
                KERNEL_DIR="$kd"
                break
            fi
        fi
    done
fi

if [ -z "$KERNEL_DIR" ] || [ ! -d "$KERNEL_DIR" ]; then
    echo "Kernel directory not found under '$OPENIPC_ROOT'. Set KERNEL_DIR to your kernel tree." >&2
    exit 1
fi

echo "Using toolchain: $TOOLCHAIN_ROOT" >&2
echo "Using CROSS_COMPILE: $CROSS_COMPILE" >&2
echo "Using kernel: $KERNEL_DIR" >&2

exec ${MAKE:-make} -C "$PROJECT_ROOT" \
    KSRC="$KERNEL_DIR" \
    CONFIG_AP_MODE=y \
    CONFIG_PROC_DEBUG=y \
    CONFIG_P2P=n \
    CONFIG_TDLS=n \
    CONFIG_POWER_SAVING=n \
    CONFIG_LAYER2_ROAMING=n \
    CONFIG_RTW_IPCAM_APPLICATION=y \
    -j"$MAKE_JOBS" \
    modules
