/*
 * Copyright (c) 2024 Smart Pet Collar Tracker
 * SPDX-License-Identifier: Apache-2.0
 *
 * Standard BLE Battery Service (UUID 0x180F).
 */

#ifndef NRF52840_BATTERY_SERVICE_H_
#define NRF52840_BATTERY_SERVICE_H_

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/** @brief Initialise the BLE Battery Service. */
int battery_service_init(void);

/**
 * @brief Update the Battery Level characteristic and send notifications.
 *
 * @param percent  Battery level 0–100 %.
 */
void battery_service_update(uint8_t percent);

#ifdef __cplusplus
}
#endif

#endif /* NRF52840_BATTERY_SERVICE_H_ */
