# Copyright (c) 2024 Smart Pet Collar Tracker
# SPDX-License-Identifier: Apache-2.0

cmake_minimum_required(VERSION 3.20.0)

find_package(Zephyr REQUIRED HINTS $ENV{ZEPHYR_BASE})
project(smart_collar_nrf9160)

# Common include directory (shared with nRF52840 firmware)
set(COMMON_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../common)

target_include_directories(app PRIVATE
    ${COMMON_DIR}/include
    src
)

# Common sources
target_sources(app PRIVATE
    ${COMMON_DIR}/src/protocol.c
    ${COMMON_DIR}/src/pet_data.c
)

# Application sources
target_sources(app PRIVATE
    src/main.c
    src/gps/gps_controller.c
    src/gps/offline_track.c
    src/lte/lte_manager.c
    src/cloud/cloud_connector.c
    src/cloud/codec.c
    src/sensors/lsm6dso_driver.c
    src/sensors/activity_classifier.c
    src/geofence/geofence_engine.c
    src/power/power_manager.c
    src/led/led_controller.c
    src/uart_bridge/uart_bridge.c
)
