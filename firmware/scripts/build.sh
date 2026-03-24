#!/usr/bin/env bash
# Smart Collar – Build Script
# Builds both nRF9160 and nRF52840 firmware using west.
#
# Usage:
#   ./scripts/build.sh [options]
#
# Options:
#   --pristine     Force clean rebuild (west build -p always)
#   --debug        Build with debug optimisations and RTT logging
#   --board-9160 <board>   Override nRF9160 board name (default: smart_collar_nrf9160)
#   --board-52840 <board>  Override nRF52840 board name (default: smart_collar_nrf52840)
#   --mqtt-endpoint <ep>   MQTT broker endpoint (overrides default placeholder)
#   -h, --help     Print this help

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIRMWARE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${FIRMWARE_DIR}/build"

# Defaults
PRISTINE_FLAG=""
BOARD_9160="smart_collar_nrf9160"
BOARD_52840="smart_collar_nrf52840"
EXTRA_CMAKE_ARGS=()
DEBUG=false

# ---- Argument parsing -------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --pristine)
            PRISTINE_FLAG="-p always"
            shift ;;
        --debug)
            DEBUG=true
            shift ;;
        --board-9160)
            BOARD_9160="$2"; shift 2 ;;
        --board-52840)
            BOARD_52840="$2"; shift 2 ;;
        --mqtt-endpoint)
            EXTRA_CMAKE_ARGS+=("-DMQTT_BROKER_ENDPOINT='\"$2\"'")
            shift 2 ;;
        -h|--help)
            head -20 "$0" | grep '^#' | sed 's/^# \?//'
            exit 0 ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1 ;;
    esac
done

if [[ "${DEBUG}" == "true" ]]; then
    EXTRA_CMAKE_ARGS+=(
        "-DCONFIG_LOG_BACKEND_RTT=y"
        "-DCONFIG_LOG_BACKEND_UART=n"
        "-DCONFIG_DEBUG_OPTIMIZATIONS=y"
        "-DCONFIG_LOG_DEFAULT_LEVEL=4"
    )
fi

# ---- Helper -----------------------------------------------------------------
build_firmware() {
    local label="$1"
    local src_dir="$2"
    local board="$3"
    local out_dir="$4"
    local overlay="$5"

    echo ""
    echo "========================================================"
    echo "  Building: ${label}"
    echo "  Board   : ${board}"
    echo "  Output  : ${out_dir}"
    echo "========================================================"

    # shellcheck disable=SC2086
    west build ${PRISTINE_FLAG} \
        -b "${board}" \
        --build-dir "${out_dir}" \
        "${src_dir}" \
        -- \
        -DBOARD_ROOT="${FIRMWARE_DIR}" \
        -DCONF_FILE=prj.conf \
        -DDTC_OVERLAY_FILE="${overlay}" \
        "${EXTRA_CMAKE_ARGS[@]+"${EXTRA_CMAKE_ARGS[@]}"}"

    echo ""
    echo "  ✓ ${label} build complete"
    echo "    Signed image : ${out_dir}/zephyr/app_signed.hex"
    echo "    Update image : ${out_dir}/zephyr/app_update.bin"
}

# ---- Sanity checks ----------------------------------------------------------
if ! command -v west &>/dev/null; then
    echo "ERROR: 'west' not found. Source the Zephyr environment first:" >&2
    echo "  source ~/ncs/zephyr/zephyr-env.sh" >&2
    exit 1
fi

mkdir -p "${BUILD_DIR}"

# ---- Build nRF9160 ----------------------------------------------------------
build_firmware \
    "nRF9160 (Cellular + GNSS)" \
    "${FIRMWARE_DIR}/nrf9160" \
    "${BOARD_9160}" \
    "${BUILD_DIR}/nrf9160" \
    "${FIRMWARE_DIR}/nrf9160/boards/${BOARD_9160}.overlay"

# ---- Build nRF52840 ---------------------------------------------------------
build_firmware \
    "nRF52840 (BLE)" \
    "${FIRMWARE_DIR}/nrf52840" \
    "${BOARD_52840}" \
    "${BUILD_DIR}/nrf52840" \
    "${FIRMWARE_DIR}/nrf52840/boards/${BOARD_52840}.overlay"

# ---- Summary ----------------------------------------------------------------
echo ""
echo "========================================================"
echo "  Build Summary"
echo "========================================================"
echo "  nRF9160  : ${BUILD_DIR}/nrf9160/zephyr/app_signed.hex"
echo "  nRF52840 : ${BUILD_DIR}/nrf52840/zephyr/app_signed.hex"
echo ""
echo "  Run './scripts/flash.sh' to flash both chips."
echo "========================================================"
