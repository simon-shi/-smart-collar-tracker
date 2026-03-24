/*
 * Copyright (c) 2024 Smart Pet Collar Tracker
 * SPDX-License-Identifier: Apache-2.0
 *
 * DFU Manager – SMP/MCUmgr OTA for nRF52840 and nRF9160.
 */

#ifndef NRF52840_DFU_MANAGER_H_
#define NRF52840_DFU_MANAGER_H_

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Initialise the DFU manager.
 *
 * Enables MCUmgr SMP over BLE transport and registers the image / OS
 * management groups.
 *
 * @return 0 on success, negative error code on failure.
 */
int dfu_manager_init(void);

/**
 * @brief Return true if a new firmware image has been received and is
 *        pending test/confirmation.
 */
bool dfu_is_update_pending(void);

/**
 * @brief Confirm the currently running image so MCUboot marks it permanent.
 *
 * @return 0 on success.
 */
int dfu_confirm_image(void);

/**
 * @brief Mark the running image as invalid and schedule a revert to the
 *        previous confirmed image on next reboot.
 */
void dfu_revert_image(void);

/**
 * @brief Register a callback invoked with DFU progress (0–100 %).
 *
 * @param cb  Progress callback.
 */
void dfu_register_progress_callback(void (*cb)(uint8_t percent));

#ifdef __cplusplus
}
#endif

#endif /* NRF52840_DFU_MANAGER_H_ */
