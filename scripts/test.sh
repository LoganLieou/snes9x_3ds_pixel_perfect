#!/bin/bash
# Build and launch caddis in Azahar for local emulator testing.
#
# Usage:
#   scripts/test.sh               # build with EMULATOR_BUILD, launch as CIA in Azahar
#   scripts/test.sh 3dsx          # build with EMULATOR_BUILD, launch as .3dsx
#
# For real hardware builds, use scripts/deploy.sh
#
# Environment overrides:
#   AZAHAR=/path/to/azahar   Azahar binary (default: /Applications/Azahar.app/...)
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="caddis"
AZAHAR="${AZAHAR:-/Applications/Azahar.app/Contents/MacOS/azahar}"
MODE="${1:-cia}"

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

if [[ ! -x "${AZAHAR}" ]]; then
    die "Azahar not found at ${AZAHAR}. Install Azahar or set AZAHAR to your emulator binary."
fi

echo "=== Building ==="
cd "${PROJECT_DIR}"
make clean
make 2>&1

THREEDSX="${PROJECT_DIR}/${TARGET}.3dsx"
ELF="${PROJECT_DIR}/${TARGET}.elf"

[[ -f "${THREEDSX}" ]] || die "Build did not produce ${THREEDSX}"
[[ -f "${ELF}" ]] || die "Build did not produce ${ELF}"

case "${MODE}" in
    3dsx)
        echo "=== Launching ${TARGET}.3dsx in Azahar ==="
        exec "${AZAHAR}" -w "${THREEDSX}"
        ;;
    cia)
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

        echo "=== Installing CIA into Azahar ==="
        "${AZAHAR}" --install "${CIA}" 2>&1

        echo "=== Opening Azahar GUI ==="
        open /Applications/Azahar.app

        echo "=== Done ==="
        ;;
    *)
        die "Unknown mode '${MODE}'. Use '3dsx' (default) or 'cia'."
        ;;
esac
