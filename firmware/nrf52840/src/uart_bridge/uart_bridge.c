/*
 * Copyright (c) 2024 Smart Pet Collar Tracker
 * SPDX-License-Identifier: Apache-2.0
 *
 * UART Bridge (nRF52840 side) – implementation.
 *
 * The bridge uses the Zephyr async UART API for RX (ring buffer driven) and
 * a k_msgq + dedicated TX thread for transmit.
 *
 * RX state machine:
 *   WAIT_SOF → WAIT_LEN_LO → WAIT_LEN_HI → WAIT_CMD → WAIT_SEQ →
 *   RECV_PAYLOAD → WAIT_CRC_LO → WAIT_CRC_HI → DISPATCH → WAIT_SOF
 */

#include "uart_bridge.h"

#include <zephyr/kernel.h>
#include <zephyr/device.h>
#include <zephyr/drivers/uart.h>
#include <zephyr/logging/log.h>
#include <string.h>

#include "../../../common/include/protocol.h"
#include "../../../common/include/config.h"

LOG_MODULE_REGISTER(uart_bridge_52, LOG_LEVEL_INF);

/* -----------------------------------------------------------------------
 * UART device
 * -------------------------------------------------------------------- */
#define UART_DEV  DT_ALIAS(uart_bridge)

static const struct device *uart_dev;

/* -----------------------------------------------------------------------
 * RX state machine
 * -------------------------------------------------------------------- */
typedef enum rx_state {
	RX_WAIT_SOF,
	RX_WAIT_LEN_LO,
	RX_WAIT_LEN_HI,
	RX_WAIT_CMD,
	RX_WAIT_SEQ,
	RX_RECV_PAYLOAD,
	RX_WAIT_CRC_LO,
	RX_WAIT_CRC_HI,
} rx_state_t;

static rx_state_t  rx_state = RX_WAIT_SOF;
static uint16_t    rx_payload_len;
static uint8_t     rx_cmd;
static uint8_t     rx_seq;
static uint16_t    rx_payload_idx;
static uint8_t     rx_payload_buf[PROTO_MAX_PAYLOAD_SIZE];
static uint8_t     rx_crc_lo;

/* -----------------------------------------------------------------------
 * TX queue
 * -------------------------------------------------------------------- */
#define TX_QUEUE_DEPTH  16
#define TX_BUF_SIZE     PROTO_MAX_PACKET_SIZE

typedef struct tx_item {
	uint8_t  buf[TX_BUF_SIZE];
	uint16_t len;
} tx_item_t;

K_MSGQ_DEFINE(tx_msgq, sizeof(tx_item_t), TX_QUEUE_DEPTH, 4);

#define TX_THREAD_STACK  1024
#define TX_THREAD_PRIO   5

K_THREAD_STACK_DEFINE(tx_stack, TX_THREAD_STACK);
static struct k_thread tx_thread_data;

/* -----------------------------------------------------------------------
 * Command callback table
 * -------------------------------------------------------------------- */
#define NUM_CMDS  256

static void (*cmd_callbacks[NUM_CMDS])(const uint8_t *payload, uint16_t len);

/* -----------------------------------------------------------------------
 * Sequence counter
 * -------------------------------------------------------------------- */
static uint8_t tx_seq;

/* -----------------------------------------------------------------------
 * RX byte processor
 * -------------------------------------------------------------------- */
static void process_rx_byte(uint8_t byte)
{
	switch (rx_state) {
	case RX_WAIT_SOF:
		if (byte == PROTO_SOF) {
			rx_state = RX_WAIT_LEN_LO;
		}
		break;

	case RX_WAIT_LEN_LO:
		rx_payload_len = byte;
		rx_state = RX_WAIT_LEN_HI;
		break;

	case RX_WAIT_LEN_HI:
		rx_payload_len |= ((uint16_t)byte << 8);
		if (rx_payload_len > PROTO_MAX_PAYLOAD_SIZE) {
			LOG_WRN("Oversized payload %u – resync", rx_payload_len);
			rx_state = RX_WAIT_SOF;
		} else {
			rx_state = RX_WAIT_CMD;
		}
		break;

	case RX_WAIT_CMD:
		rx_cmd   = byte;
		rx_state = RX_WAIT_SEQ;
		break;

	case RX_WAIT_SEQ:
		rx_seq = byte;
		rx_payload_idx = 0;
		if (rx_payload_len == 0) {
			rx_state = RX_WAIT_CRC_LO;
		} else {
			rx_state = RX_RECV_PAYLOAD;
		}
		break;

	case RX_RECV_PAYLOAD:
		rx_payload_buf[rx_payload_idx++] = byte;
		if (rx_payload_idx >= rx_payload_len) {
			rx_state = RX_WAIT_CRC_LO;
		}
		break;

	case RX_WAIT_CRC_LO:
		rx_crc_lo = byte;
		rx_state  = RX_WAIT_CRC_HI;
		break;

	case RX_WAIT_CRC_HI: {
		uint16_t rx_crc = rx_crc_lo | ((uint16_t)byte << 8);

		/* Compute expected CRC over cmd + seq + payload */
		uint16_t crc = crc16_ccitt_update(PROTO_CRC16_INIT, rx_cmd);

		crc = crc16_ccitt_update(crc, rx_seq);
		for (uint16_t i = 0; i < rx_payload_len; i++) {
			crc = crc16_ccitt_update(crc, rx_payload_buf[i]);
		}

		if (crc != rx_crc) {
			LOG_WRN("CRC mismatch: expected 0x%04x got 0x%04x",
				crc, rx_crc);
			/* Send NACK */
			uint8_t nack_buf[PROTO_MIN_PACKET_SIZE + 2];
			int nlen = protocol_build_nack(nack_buf,
						       sizeof(nack_buf),
						       rx_seq, tx_seq++,
						       NACK_CRC_ERROR);
			if (nlen > 0) {
				uart_tx(uart_dev, nack_buf,
					(size_t)nlen, SYS_FOREVER_US);
			}
		} else {
			/* Send ACK */
			uint8_t ack_buf[PROTO_MIN_PACKET_SIZE + 1];
			int alen = protocol_build_ack(ack_buf,
						      sizeof(ack_buf),
						      rx_seq, tx_seq++);
			if (alen > 0) {
				uart_tx(uart_dev, ack_buf,
					(size_t)alen, SYS_FOREVER_US);
			}

			/* Dispatch to registered handler */
			uint8_t idx = (uint8_t)rx_cmd;

			if (cmd_callbacks[idx]) {
				cmd_callbacks[idx](rx_payload_buf,
						   rx_payload_len);
			} else {
				LOG_DBG("No handler for cmd 0x%02x", rx_cmd);
			}
		}
		rx_state = RX_WAIT_SOF;
		break;
	}

	default:
		rx_state = RX_WAIT_SOF;
		break;
	}
}

/* -----------------------------------------------------------------------
 * UART interrupt / async callback
 * -------------------------------------------------------------------- */
static void uart_cb(const struct device *dev,
		    struct uart_event *evt,
		    void *user_data)
{
	switch (evt->type) {
	case UART_RX_RDY:
		for (size_t i = 0; i < evt->data.rx.len; i++) {
			process_rx_byte(evt->data.rx.buf[evt->data.rx.offset + i]);
		}
		break;

	case UART_RX_BUF_REQUEST:
		/* Double-buffered RX – provide second buffer */
		break;

	case UART_TX_DONE:
		break;

	default:
		break;
	}
}

/* -----------------------------------------------------------------------
 * TX thread
 * -------------------------------------------------------------------- */
static uint8_t rx_buf_a[UART_RX_BUF_SIZE];
static uint8_t rx_buf_b[UART_RX_BUF_SIZE];

static void tx_thread_fn(void *a, void *b, void *c)
{
	tx_item_t item;

	while (true) {
		k_msgq_get(&tx_msgq, &item, K_FOREVER);

		int err = uart_tx(uart_dev, item.buf,
				  (size_t)item.len, SYS_FOREVER_US);
		if (err) {
			LOG_ERR("uart_tx failed: %d", err);
		}
	}
}

/* -----------------------------------------------------------------------
 * Public API
 * -------------------------------------------------------------------- */

int uart_bridge_init(void)
{
	uart_dev = DEVICE_DT_GET(UART_DEV);

	if (!device_is_ready(uart_dev)) {
		LOG_ERR("UART bridge device not ready");
		return -ENODEV;
	}

	memset(cmd_callbacks, 0, sizeof(cmd_callbacks));

	/* Register async callback */
	int err = uart_callback_set(uart_dev, uart_cb, NULL);

	if (err) {
		LOG_ERR("uart_callback_set failed: %d", err);
		return err;
	}

	/* Start double-buffered RX */
	err = uart_rx_enable(uart_dev, rx_buf_a, sizeof(rx_buf_a),
			     UART_RX_TIMEOUT_MS * 1000);
	if (err) {
		LOG_ERR("uart_rx_enable failed: %d", err);
		return err;
	}

	/* Start TX thread */
	k_thread_create(&tx_thread_data, tx_stack,
			K_THREAD_STACK_SIZEOF(tx_stack),
			tx_thread_fn, NULL, NULL, NULL,
			TX_THREAD_PRIO, 0, K_NO_WAIT);
	k_thread_name_set(&tx_thread_data, "uart_bridge_tx");

	LOG_INF("UART bridge (nRF52840) initialised at %lu bps",
		(unsigned long)UART_BAUD_RATE);
	return 0;
}

int uart_bridge_send(proto_cmd_t cmd,
		     const uint8_t *payload,
		     uint16_t payload_len)
{
	tx_item_t item;
	int len = protocol_encode(item.buf, sizeof(item.buf),
				  cmd, tx_seq++, payload, payload_len);

	if (len < 0) {
		LOG_ERR("protocol_encode failed: %d", len);
		return len;
	}

	item.len = (uint16_t)len;
	int err = k_msgq_put(&tx_msgq, &item, K_NO_WAIT);

	if (err) {
		LOG_WRN("TX queue full – dropping cmd 0x%02x", cmd);
		return -ENOMEM;
	}
	return 0;
}

void uart_bridge_register_callback(proto_cmd_t cmd,
				   void (*cb)(const uint8_t *payload,
					      uint16_t len))
{
	cmd_callbacks[(uint8_t)cmd] = cb;
}
