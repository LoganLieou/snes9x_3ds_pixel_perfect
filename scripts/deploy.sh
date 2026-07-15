#!/bin/bash
# Build caddis for real 3DS hardware (no EMULATOR_BUILD path).
#
# Usage:
#   scripts/deploy.sh              # build CIA for real hardware
#   scripts/deploy.sh install      # build + install CIA in Azahar (for comparison)
#
# Environment overrides:
#   AZAHAR=/path/to/azahar   Azahar binary (default: /Applications/Azahar.app/...)
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="caddis"
AZAHAR="${AZAHAR:-/Applications/Azahar.app/Contents/MacOS/azahar}"

die() {
    echo "error: $*" >&2
    exit 1
}

find_makerom() {
    local uname_s uname_m
    uname_s="$(uname -s)"
    uname_m="$(uname -m)"

    case "${uname_s}" in
        Darwin)
            echo "${PROJECT_DIR}/makerom/darwin_x86_64/makerom"
            ;;
        Linux)
            if [[ "${uname_m}" == "x86_64" ]]; then
                echo "${PROJECT_DIR}/makerom/linux_x86_64/makerom"
            fi
            ;;
        CYGWIN_NT*|MINGW*)
            echo "${PROJECT_DIR}/makerom/windows_x86_64/makerom.exe"
            ;;
    esac
}

if [[ -z "${DEVKITARM:-}" ]]; then
    die "DEVKITARM is not set. Install devkitARM and run: export DEVKITARM=/opt/devkitpro/devkitARM"
fi

echo "=== Building for real 3DS hardware (EMULATOR_BUILD=0) ==="
cd "${PROJECT_DIR}"
make clean
make EMULATOR_BUILD=0 2>&1

THREEDSX="${PROJECT_DIR}/${TARGET}.3dsx"
ELF="${PROJECT_DIR}/${TARGET}.elf"

[[ -f "${THREEDSX}" ]] || die "Build did not produce ${THREEDSX}"
[[ -f "${ELF}" ]] || die "Build did not produce ${ELF}"

MAKEROM="$(find_makerom)"
[[ -n "${MAKEROM}" && -x "${MAKEROM}" ]] || die "makerom not found for $(uname -s)/$(uname -m)"

CIA="${PROJECT_DIR}/${TARGET}.cia"
echo "=== Building CIA ==="
"${MAKEROM}" \
    -rsf "${PROJECT_DIR}/${TARGET}.rsf" \
    -elf "${ELF}" \
    -icon "${PROJECT_DIR}/${TARGET}.icn" \
    -banner "${PROJECT_DIR}/${TARGET}.bnr" \
    -f cia \
    -o "${CIA}" 2>&1

echo "=== CIA ready: ${CIA} ==="
echo "Copy to 3DS SD card and install with FBI."

if [[ "${1:-}" == "install" ]]; then
    if [[ -x "${AZAHAR}" ]]; then
        echo "=== Installing in Azahar (for comparison) ==="
        "${AZAHAR}" --install "${CIA}" 2>&1
        echo "=== Opening Azahar GUI ==="
        open /Applications/Azahar.app
    fi
fi