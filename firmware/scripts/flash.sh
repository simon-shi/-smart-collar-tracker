#!/usr/bin/env bash
# Smart Collar – Flash Script
# Flashes both nRF9160 and nRF52840 using nrfjprog / west flash.
#
# Usage:
#   ./scripts/flash.sh [options]
#
# Options:
#   --only-9160      Flash only the nRF9160
#   --only-52840     Flash only the nRF52840
#   --recover        Run --recover before flashing (use after hard brick)
#   --snr <serial>   J-Link serial number (for multi-probe setups)
#   --west           Use 'west flash' instead of nrfjprog directly
#   -h, --help       Print this help

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIRMWARE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${FIRMWARE_DIR}/build"

# Defaults
FLASH_9160=true
FLASH_52840=true
RECOVER=false
JLINK_SNR=""
USE_WEST=false

# ---- Argument parsing -------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --only-9160)   FLASH_52840=false; shift ;;
        --only-52840)  FLASH_9160=false;  shift ;;
        --recover)     RECOVER=true;       shift ;;
        --snr)         JLINK_SNR="$2";    shift 2 ;;
        --west)        USE_WEST=true;      shift ;;
        -h|--help)
            head -20 "$0" | grep '^#' | sed 's/^# \?//'
            exit 0 ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1 ;;
    esac
done

SNR_ARG=""
if [[ -n "${JLINK_SNR}" ]]; then
    SNR_ARG="--snr ${JLINK_SNR}"
fi

# ---- Helper: check binary exists -------------------------------------------
check_binary() {
    local label="$1"
    local path="$2"
    if [[ ! -f "${path}" ]]; then
        echo "ERROR: ${label} binary not found: ${path}" >&2
        echo "  Run './scripts/build.sh' first." >&2
        exit 1
    fi
}

# ---- Flash nRF9160 ----------------------------------------------------------
flash_nrf9160() {
    local hex="${BUILD_DIR}/nrf9160/zephyr/merged.hex"
    check_binary "nRF9160" "${hex}"

    echo ""
    echo "========================================================"
    echo "  Flashing nRF9160 (Cellular + GNSS)"
    echo "========================================================"

    if [[ "${USE_WEST}" == "true" ]]; then
        west flash --build-dir "${BUILD_DIR}/nrf9160" --runner nrfjprog
    else
        if [[ "${RECOVER}" == "true" ]]; then
            echo "  Recovering nRF9160..."
            # shellcheck disable=SC2086
            nrfjprog --recover --coprocessor CP_Application ${SNR_ARG}
        fi
        # shellcheck disable=SC2086
        nrfjprog --program "${hex}" \
                 --sectorerase \
                 --coprocessor CP_Application \
                 ${SNR_ARG}
        # shellcheck disable=SC2086
        nrfjprog --reset --coprocessor CP_Application ${SNR_ARG}
    fi

    echo "  ✓ nRF9160 flashed successfully"
}

# ---- Flash nRF52840 ---------------------------------------------------------
flash_nrf52840() {
    local hex="${BUILD_DIR}/nrf52840/zephyr/merged.hex"
    check_binary "nRF52840" "${hex}"

    echo ""
    echo "========================================================"
    echo "  Flashing nRF52840 (BLE)"
    echo "========================================================"

    if [[ "${USE_WEST}" == "true" ]]; then
        west flash --build-dir "${BUILD_DIR}/nrf52840" --runner nrfjprog
    else
        if [[ "${RECOVER}" == "true" ]]; then
            echo "  Recovering nRF52840..."
            # shellcheck disable=SC2086
            nrfjprog --recover ${SNR_ARG}
        fi
        # shellcheck disable=SC2086
        nrfjprog --program "${hex}" --sectorerase ${SNR_ARG}
        # shellcheck disable=SC2086
        nrfjprog --reset ${SNR_ARG}
    fi

    echo "  ✓ nRF52840 flashed successfully"
}

# ---- Sanity check -----------------------------------------------------------
if ! command -v nrfjprog &>/dev/null && [[ "${USE_WEST}" == "false" ]]; then
    echo "ERROR: 'nrfjprog' not found." >&2
    echo "  Install nRF Command Line Tools from:" >&2
    echo "  https://www.nordicsemi.com/Products/Development-tools/nRF-Command-Line-Tools" >&2
    exit 1
fi

# ---- Run flashing -----------------------------------------------------------
if [[ "${FLASH_9160}" == "true" ]]; then
    flash_nrf9160
fi

if [[ "${FLASH_52840}" == "true" ]]; then
    flash_nrf52840
fi

echo ""
echo "========================================================"
echo "  Flash complete. Connect to serial console:"
echo "    nRF9160  : minicom -D /dev/ttyACM0 -b 115200"
echo "    nRF52840 : minicom -D /dev/ttyACM1 -b 115200"
echo "========================================================"
