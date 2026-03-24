/*
 * Copyright (c) 2024 Smart Pet Collar Tracker
 * SPDX-License-Identifier: Apache-2.0
 */
#ifndef FIRMWARE_NRF9160_UART_BRIDGE_H_
#define FIRMWARE_NRF9160_UART_BRIDGE_H_
#include <stdint.h>
#include "protocol.h"
#ifdef __cplusplus
extern "C" {
#endif
int uart_bridge_init(void);
int uart_bridge_send(proto_cmd_t cmd, const uint8_t *payload, uint16_t payload_len);
void uart_bridge_register_callback(proto_cmd_t cmd, void (*cb)(const uint8_t *payload, uint16_t len));
#ifdef __cplusplus
}
#endif
#endif
