/*
 * Copyright (c) 2024 Smart Pet Collar Tracker
 * SPDX-License-Identifier: Apache-2.0
 *
 * Custom Pet Tracker GATT Service
 *
 * Service UUID:        12345678-1234-5678-1234-56789abcdef0
 * Characteristic UUIDs:
 *   Location     (N):  12345678-1234-5678-1234-56789abcdef1
 *   Activity     (N):  12345678-1234-5678-1234-56789abcdef2
 *   Geofence Alert(N): 12345678-1234-5678-1234-56789abcdef3
 *   Device Control(W): 12345678-1234-5678-1234-56789abcdef4
 *   Device Status (R): 12345678-1234-5678-1234-56789abcdef5
 *   Offline Sync  (N): 12345678-1234-5678-1234-56789abcdef6
 */

#ifndef NRF52840_PET_TRACKER_SERVICE_H_
#define NRF52840_PET_TRACKER_SERVICE_H_

#include <stdint.h>
#include <zephyr/bluetooth/conn.h>
#include "../../../common/include/pet_data.h"

#ifdef __cplusplus
extern "C" {
#endif

/** @brief Initialise the Pet Tracker GATT service. */
int pet_tracker_service_init(void);

/** @brief Send a Location notification on @p conn. */
int pet_tracker_notify_location(struct bt_conn *conn,
				const pet_location_t *loc);

/** @brief Send an Activity notification on @p conn. */
int pet_tracker_notify_activity(struct bt_conn *conn,
				const pet_activity_data_t *act);

/** @brief Send a Geofence Alert notification on @p conn. */
int pet_tracker_notify_geofence_alert(struct bt_conn *conn,
				      const geofence_alert_t *alert);

/** @brief Update the Device Status characteristic value. */
int pet_tracker_update_status(const device_status_t *status);

/**
 * @brief Register a callback for Device Control writes from the peer.
 *
 * @param cb  Invoked with the raw write data when the peer writes to the
 *            Device Control characteristic.  Called in BT RX thread context.
 */
void pet_tracker_register_control_callback(
	void (*cb)(const uint8_t *data, uint16_t len));

#ifdef __cplusplus
}
#endif

#endif /* NRF52840_PET_TRACKER_SERVICE_H_ */
