/*
 * Copyright (c) 2024 Smart Pet Collar Tracker
 * SPDX-License-Identifier: Apache-2.0
 */
#ifndef FIRMWARE_NRF9160_POWER_MANAGER_H_
#define FIRMWARE_NRF9160_POWER_MANAGER_H_
#include <stdint.h>
#include "pet_data.h"
#ifdef __cplusplus
extern "C" {
#endif
int power_manager_init(void);
void power_set_mode(power_mode_t mode);
power_mode_t power_get_mode(void);
uint8_t power_get_battery_percent(void);
uint16_t power_get_battery_mv(void);
void power_register_battery_callback(void (*cb)(uint8_t percent));
#ifdef __cplusplus
}
#endif
#endif /* FIRMWARE_NRF9160_POWER_MANAGER_H_ */
