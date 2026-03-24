/*
 * Copyright (c) 2024 Smart Pet Collar Tracker
 * SPDX-License-Identifier: Apache-2.0
 *
 * iBeacon / Beacon manager for crowd-sourced pet finding.
 */

#ifndef NRF52840_BEACON_MANAGER_H_
#define NRF52840_BEACON_MANAGER_H_

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Initialise the beacon manager.
 *
 * Registers a k_timer that alternates between connectable and beacon
 * advertising when the device is not connected.
 *
 * @return 0 on success.
 */
int beacon_manager_init(void);

/** @brief Start iBeacon non-connectable advertising. */
void beacon_start(void);

/** @brief Stop beacon advertising. */
void beacon_stop(void);

/**
 * @brief Set the iBeacon proximity UUID, major, and minor values.
 *
 * @param uuid   16-byte proximity UUID (big-endian).
 * @param major  Major value.
 * @param minor  Minor value.
 */
void beacon_set_params(const uint8_t uuid[16],
		       uint16_t major,
		       uint16_t minor);

#ifdef __cplusplus
}
#endif

#endif /* NRF52840_BEACON_MANAGER_H_ */
