/*
 * Copyright (c) 2024 Smart Pet Collar Tracker
 * SPDX-License-Identifier: Apache-2.0
 *
 * Charge Manager – magnetic 4-pin connector detection, nPM1100 charge state.
 */

#ifndef NRF52840_CHARGE_MANAGER_H_
#define NRF52840_CHARGE_MANAGER_H_

#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Initialise the charge manager.
 *
 * Configures GPIO interrupts for connector detection and CHG_STAT.
 *
 * @return 0 on success, negative error code on failure.
 */
int charge_manager_init(void);

/**
 * @brief Return true if the magnetic connector is attached (power or data).
 */
bool charge_is_connected(void);

/**
 * @brief Return true if the battery is currently being charged.
 */
bool charge_is_charging(void);

/**
 * @brief Register a callback for charge events.
 *
 * @param cb  Invoked with (connector_present, is_charging) on any state
 *            change.
 */
void charge_register_callback(void (*cb)(bool connected, bool charging));

#ifdef __cplusplus
}
#endif

#endif /* NRF52840_CHARGE_MANAGER_H_ */
