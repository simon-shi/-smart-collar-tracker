/*
 * Copyright (c) 2024 Smart Pet Collar Tracker
 * SPDX-License-Identifier: Apache-2.0
 */

#ifndef FIRMWARE_NRF9160_GPS_CONTROLLER_H_
#define FIRMWARE_NRF9160_GPS_CONTROLLER_H_

#include <stdint.h>
#include <stdbool.h>
#include "pet_data.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Initialise the GPS controller.
 *
 * Initialises nrf_modem_gnss and configures PVT output mode.
 * Must be called after lte_manager_init() because the modem must be
 * initialised first.
 *
 * @return 0 on success, negative errno on failure.
 */
int gps_controller_init(void);

/**
 * @brief Start periodic GPS fix acquisition.
 *
 * Schedules the first fix attempt immediately and subsequent attempts
 * every interval set by gps_set_fix_interval().
 *
 * @return 0 on success, negative errno on failure.
 */
int gps_controller_start(void);

/**
 * @brief Stop GPS fix acquisition and put GNSS into power-off state.
 *
 * @return 0 on success, negative errno on failure.
 */
int gps_controller_stop(void);

/**
 * @brief Set the periodic GPS fix interval.
 *
 * @param interval_s  Fix attempt interval in seconds. 0 = disable.
 */
void gps_set_fix_interval(uint32_t interval_s);

/**
 * @brief Register a callback invoked on every valid GPS fix.
 *
 * Only one callback is supported; subsequent calls replace the previous one.
 *
 * @param cb  Callback function pointer. May be NULL to unregister.
 */
void gps_register_fix_callback(void (*cb)(const struct pet_location *loc));

/**
 * @brief Inject A-GPS assistance data into the modem.
 *
 * Called with data fetched from the cloud; improves TTFF significantly.
 *
 * @param data  A-GPS data buffer.
 * @param len   Length of data in bytes.
 *
 * @return 0 on success, negative errno on failure.
 */
int gps_inject_agps_data(const uint8_t *data, size_t len);

/**
 * @brief Return the last known GPS fix.
 *
 * @param[out] loc  Populated with the last valid fix on success.
 *
 * @return 0 if a valid fix is available, -ENODATA if no fix yet.
 */
int gps_get_last_fix(struct pet_location *loc);

/**
 * @brief Trigger an immediate single-shot GPS fix (e.g. after wake-on-motion).
 *
 * Does not affect the periodic schedule; the next periodic fix fires at the
 * normal time.
 *
 * @return 0 on success, negative errno on failure.
 */
int gps_trigger_single_fix(void);

#ifdef __cplusplus
}
#endif

#endif /* FIRMWARE_NRF9160_GPS_CONTROLLER_H_ */
