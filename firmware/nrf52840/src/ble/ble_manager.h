/*
 * Copyright (c) 2024 Smart Pet Collar Tracker
 * SPDX-License-Identifier: Apache-2.0
 *
 * BLE Manager – stack initialisation, advertising, connection management.
 */

#ifndef NRF52840_BLE_MANAGER_H_
#define NRF52840_BLE_MANAGER_H_

#include <stdbool.h>
#include <stdint.h>
#include <zephyr/bluetooth/bluetooth.h>
#include <zephyr/bluetooth/conn.h>

#include "../../common/include/pet_data.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Initialise the BLE stack and register GATT services.
 *
 * Must be called once before any other ble_* function.
 *
 * @return 0 on success, negative error code on failure.
 */
int ble_manager_init(void);

/**
 * @brief Start BLE advertising.
 *
 * @param connectable  true → connectable + scannable advertising;
 *                     false → non-connectable beacon advertising.
 */
void ble_start_advertising(bool connectable);

/**
 * @brief Stop BLE advertising.
 */
void ble_stop_advertising(void);

/**
 * @brief Return true if at least one BLE connection is active.
 */
bool ble_is_connected(void);

/**
 * @brief Return the number of active BLE connections.
 */
int ble_connection_count(void);

/**
 * @brief Register a callback for connection/disconnection events.
 *
 * @param cb  Callback: true = connected, false = disconnected.
 */
void ble_register_connection_callback(void (*cb)(bool connected));

/**
 * @brief Send a location notification to all subscribed connections.
 *
 * @param loc  Pointer to the GPS fix to forward.
 */
void ble_send_location_notification(const pet_location_t *loc);

/**
 * @brief Send an activity notification to all subscribed connections.
 *
 * @param act  Pointer to the activity record to forward.
 */
void ble_send_activity_notification(const pet_activity_data_t *act);

/**
 * @brief Send a geofence alert notification to all subscribed connections.
 *
 * @param alert  Pointer to the geofence alert to forward.
 */
void ble_send_geofence_alert(const geofence_alert_t *alert);

#ifdef __cplusplus
}
#endif

#endif /* NRF52840_BLE_MANAGER_H_ */
