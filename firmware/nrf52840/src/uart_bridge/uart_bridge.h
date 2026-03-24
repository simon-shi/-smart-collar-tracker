/*
 * Copyright (c) 2024 Smart Pet Collar Tracker
 * SPDX-License-Identifier: Apache-2.0
 *
 * UART Bridge (nRF52840 side) – inter-chip communication with nRF9160.
 */

#ifndef NRF52840_UART_BRIDGE_H_
#define NRF52840_UART_BRIDGE_H_

#include <stdint.h>
#include "../../../common/include/protocol.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Initialise the UART bridge.
 *
 * Configures the UART device at UART_BAUD_RATE (1 Mbps), installs the
 * interrupt-driven RX state machine, and creates the TX message queue
 * thread.
 *
 * @return 0 on success, negative error code on failure.
 */
int uart_bridge_init(void);

/**
 * @brief Send a protocol packet to the nRF9160.
 *
 * The function encodes the packet and places it in the TX queue.  It does
 * NOT block until the transmission completes.
 *
 * @param cmd          Command identifier.
 * @param payload      Payload bytes (may be NULL when payload_len == 0).
 * @param payload_len  Number of payload bytes.
 *
 * @return 0 on success, -ENOMEM if the TX queue is full, other negative
 *         codes on encoding failure.
 */
int uart_bridge_send(proto_cmd_t cmd,
		     const uint8_t *payload,
		     uint16_t payload_len);

/**
 * @brief Register a handler for a specific received command.
 *
 * Only one handler per command is supported.  A second registration
 * silently replaces the previous one.
 *
 * @param cmd  Command to intercept.
 * @param cb   Callback invoked in the RX thread context.
 */
void uart_bridge_register_callback(proto_cmd_t cmd,
				   void (*cb)(const uint8_t *payload,
					      uint16_t len));

#ifdef __cplusplus
}
#endif

#endif /* NRF52840_UART_BRIDGE_H_ */
