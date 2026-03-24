/*
 * Copyright (c) 2024 Smart Pet Collar Tracker
 * SPDX-License-Identifier: Apache-2.0
 */

#ifndef FIRMWARE_NRF9160_LTE_MANAGER_H_
#define FIRMWARE_NRF9160_LTE_MANAGER_H_

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief LTE manager event types delivered to the registered callback.
 */
enum lte_event {
	LTE_EVENT_CONNECTED,      /**< LTE bearer is up and IP address assigned. */
	LTE_EVENT_DISCONNECTED,   /**< LTE bearer went down.                     */
	LTE_EVENT_CONNECTING,     /**< Connection attempt in progress.           */
	LTE_EVENT_PSM_UPDATE,     /**< PSM parameters updated by network.        */
	LTE_EVENT_EDRX_UPDATE,    /**< eDRX parameters updated by network.       */
	LTE_EVENT_CELL_UPDATE,    /**< Serving cell changed.                     */
	LTE_EVENT_NO_COVERAGE,    /**< No LTE coverage – offline mode.           */
};

/**
 * @brief Initialise the LTE manager.
 *
 * Registers modem library callbacks and configures RAT, PSM, and eDRX
 * parameters via AT commands.  Does not start a connection attempt.
 *
 * @return 0 on success, negative errno on failure.
 */
int lte_manager_init(void);

/**
 * @brief Start an asynchronous LTE connection attempt.
 *
 * Returns immediately; connection result is delivered via the registered
 * event callback.  Implements exponential back-off on failure.
 *
 * @return 0 if the connection attempt was queued, negative errno on failure.
 */
int lte_manager_connect(void);

/**
 * @brief Disconnect from LTE and enter PSM / airplane mode.
 *
 * @return 0 on success, negative errno on failure.
 */
int lte_manager_disconnect(void);

/**
 * @brief Query whether an LTE data bearer is currently active.
 *
 * @return true if connected, false otherwise.
 */
bool lte_is_connected(void);

/**
 * @brief Read the current LTE signal quality indicators.
 *
 * @param[out] rsrp  Reference Signal Received Power in dBm (negative).
 *                   Set to INT_MIN if unavailable.
 * @param[out] rsrq  Reference Signal Received Quality in dB (negative).
 *                   Set to INT_MIN if unavailable.
 *
 * @return 0 on success, negative errno on failure.
 */
int lte_get_signal_quality(int *rsrp, int *rsrq);

/**
 * @brief Register a callback for LTE events.
 *
 * Only one callback is supported; subsequent calls replace the previous one.
 *
 * @param cb  Function pointer to invoke on LTE events. May be NULL.
 */
void lte_register_event_callback(void (*cb)(enum lte_event event));

#ifdef __cplusplus
}
#endif

#endif /* FIRMWARE_NRF9160_LTE_MANAGER_H_ */
