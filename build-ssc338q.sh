#!/usr/bin/env bash
# Helper script for building the 8812au module for the Sigmastar SSC338Q SoC.
#
# The script mirrors the helper that exists on the main branch and provides a
# reproducible way to cross-compile the module with only the features needed
# for AP mode enabled.
#
# Usage examples:
#   SSC338Q_KERNEL_DIR=/path/to/linux \
#   SSC338Q_TOOLCHAIN_PREFIX=/opt/sigmastar/toolchain/bin/arm-linux-gnueabihf- \
#   ./build-ssc338q.sh
#
#   ./build-ssc338q.sh --kernel-dir /path/to/linux --output-dir artifacts
#
# Environment overrides:
#   SSC338Q_KERNEL_DIR      - Location of the SSC338Q kernel tree
#   SSC338Q_TOOLCHAIN_PREFIX- Cross-compiler prefix (without the gcc suffix)
#   SSC338Q_ARCH            - Target ARCH (default: arm)
#   SSC338Q_MAKE_JOBS       - Override the number of make jobs (defaults to nproc)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}"
SCRIPT_NAME="$(basename "$0")"

usage() {
        cat <<USAGE
Usage: ${SCRIPT_NAME} [--kernel-dir <path>] [--output-dir <path>] [--help]

Options:
  -k, --kernel-dir PATH   Path to the SSC338Q kernel source tree.
                          Defaults to \$SSC338Q_KERNEL_DIR.
  -o, --output-dir PATH   Directory where the built 8812au.ko will be copied.
                          Defaults to <repo>/build/ssc338q.
  -h, --help              Print this message and exit.
USAGE
}

KERNEL_DIR="${SSC338Q_KERNEL_DIR:-}"
OUTPUT_DIR=""

while [[ $# -gt 0 ]]; do
        case "$1" in
        -k|--kernel-dir)
                [[ $# -lt 2 ]] && { echo "error: missing value for $1" >&2; usage; exit 1; }
                KERNEL_DIR="$2"
                shift 2
                ;;
        -o|--output-dir)
                [[ $# -lt 2 ]] && { echo "error: missing value for $1" >&2; usage; exit 1; }
                OUTPUT_DIR="$2"
                shift 2
                ;;
        -h|--help)
                usage
                exit 0
                ;;
        *)
                echo "error: unknown option $1" >&2
                usage
                exit 1
                ;;
        esac
done

if [[ -z "${KERNEL_DIR}" ]]; then
        echo "error: SSC338Q kernel directory was not provided." >&2
        echo "       Set SSC338Q_KERNEL_DIR or pass --kernel-dir." >&2
        exit 1
fi

if [[ ! -d "${KERNEL_DIR}" ]]; then
        echo "error: kernel directory '${KERNEL_DIR}' does not exist." >&2
        exit 1
fi

OUTPUT_DIR="${OUTPUT_DIR:-${PROJECT_ROOT}/build/ssc338q}"
mkdir -p "${OUTPUT_DIR}"

ARCH="${SSC338Q_ARCH:-arm}"
TOOLCHAIN_PREFIX="${SSC338Q_TOOLCHAIN_PREFIX:-/opt/sigmastar/toolchain/bin/arm-linux-gnueabihf-}"

if [[ ! -x "${TOOLCHAIN_PREFIX}gcc" ]]; then
        echo "error: cross-compiler '${TOOLCHAIN_PREFIX}gcc' was not found or is not executable." >&2
        echo "       Set SSC338Q_TOOLCHAIN_PREFIX to the toolchain used on the main branch." >&2
        exit 1
fi

MAKE_JOBS="${SSC338Q_MAKE_JOBS:-$(nproc)}"

CONFIG_OVERRIDES=(
        CONFIG_AP_MODE=y
        CONFIG_P2P=n
        CONFIG_TDLS=n
        CONFIG_WIFI_MONITOR=n
        CONFIG_RTW_MBO=n
        CONFIG_RTW_REPEATER_SON=n
        CONFIG_RTW_IPCAM_APPLICATION=n
        CONFIG_RTW_MESH=n
        CONFIG_MP_INCLUDED=n
        CONFIG_POWER_SAVING=y
        CONFIG_BR_EXT=y
)

pushd "${PROJECT_ROOT}" >/dev/null

echo "[*] Cleaning previous build artifacts..."
make clean >/dev/null

echo "[*] Building 8812au.ko for SSC338Q (ARCH=${ARCH})..."
make \
        ARCH="${ARCH}" \
        CROSS_COMPILE="${TOOLCHAIN_PREFIX}" \
        KSRC="${KERNEL_DIR}" \
        "${CONFIG_OVERRIDES[@]}" \
        -j"${MAKE_JOBS}" \
        modules

cp -v 8812au.ko "${OUTPUT_DIR}/"
echo "[+] Build complete. Module copied to ${OUTPUT_DIR}/8812au.ko"

popd >/dev/null
