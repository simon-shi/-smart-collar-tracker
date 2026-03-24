cmake_minimum_required(VERSION 3.20.0)
find_package(Zephyr REQUIRED HINTS $ENV{ZEPHYR_BASE})

project(smart_collar_nrf52840)

# Common include path
set(COMMON_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../common)

target_include_directories(app PRIVATE
    ${COMMON_DIR}/include
    src
)

target_sources(app PRIVATE
    src/main.c
    src/ble/ble_manager.c
    src/ble/services/pet_tracker_service.c
    src/ble/services/battery_service.c
    src/ble/services/device_info_service.c
    src/ble/beacon/beacon_manager.c
    src/dfu/dfu_manager.c
    src/flash/flash_manager.c
    src/charge/charge_manager.c
    src/uart_bridge/uart_bridge.c
    ${COMMON_DIR}/src/protocol.c
    ${COMMON_DIR}/src/pet_data.c
)
