/*
 * Copyright (c) 2024 Smart Pet Collar Tracker
 * SPDX-License-Identifier: Apache-2.0
 */
#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>
#include <zephyr/drivers/uart.h>
#include <zephyr/devicetree.h>
#include <string.h>
#include "uart_bridge.h"
#include "protocol.h"
#include "config.h"

LOG_MODULE_REGISTER(uart_bridge, LOG_LEVEL_INF);

#define UART_NODE  DT_NODELABEL(uart1)
#define MAX_CBS    16U

static const struct device *uart_dev;
static uint8_t seq_no;

/* TX message queue */
static uint8_t tx_msgq_buf[8 * PROTO_MAX_PACKET_SIZE];
K_MSGQ_DEFINE(tx_queue, PROTO_MAX_PACKET_SIZE, 8, 4);

/* RX state machine */
typedef enum { RX_WAIT_SOF, RX_LENGTH_LO, RX_LENGTH_HI, RX_CMD, RX_SEQNO, RX_PAYLOAD, RX_CRC_LO, RX_CRC_HI } rx_state_t;
static rx_state_t rx_state = RX_WAIT_SOF;
static uint8_t rx_pkt[PROTO_MAX_PACKET_SIZE];
static uint16_t rx_len, rx_pos;
static uint8_t rx_cmd, rx_seq;

/* Callbacks */
static struct { proto_cmd_t cmd; void (*cb)(const uint8_t *, uint16_t); } cbs[MAX_CBS];
static uint8_t num_cbs;

static void dispatch(proto_cmd_t cmd, const uint8_t *payload, uint16_t len)
{
	for (uint8_t i = 0; i < num_cbs; i++) {
		if (cbs[i].cmd == cmd && cbs[i].cb) {
			cbs[i].cb(payload, len);
			return;
		}
	}
}

static void uart_cb(const struct device *dev, struct uart_event *evt, void *user_data)
{
	if (evt->type != UART_RX_RDY) return;
	const uint8_t *data = evt->data.rx.buf + evt->data.rx.offset;
	size_t len = evt->data.rx.len;

	for (size_t i = 0; i < len; i++) {
		uint8_t b = data[i];
		switch (rx_state) {
		case RX_WAIT_SOF:
			if (b == PROTO_SOF) { rx_state = RX_LENGTH_LO; rx_pos = 0; }
			break;
		case RX_LENGTH_LO: rx_len = b; rx_state = RX_LENGTH_HI; break;
		case RX_LENGTH_HI:
			rx_len |= (uint16_t)(b << 8);
			if (rx_len > PROTO_MAX_PAYLOAD_SIZE) { rx_state = RX_WAIT_SOF; break; }
			rx_state = RX_CMD; break;
		case RX_CMD: rx_cmd = b; rx_state = RX_SEQNO; break;
		case RX_SEQNO:
			rx_seq = b;
			rx_pos = 0;
			rx_state = (rx_len > 0) ? RX_PAYLOAD : RX_CRC_LO;
			break;
		case RX_PAYLOAD:
			rx_pkt[rx_pos++] = b;
			if (rx_pos >= rx_len) rx_state = RX_CRC_LO;
			break;
		case RX_CRC_LO: rx_pkt[rx_pos] = b; rx_state = RX_CRC_HI; break;
		case RX_CRC_HI: {
			/* Verify CRC */
			uint16_t stored = (uint16_t)(rx_pkt[rx_pos] | (b << 8));
			uint8_t crc_buf[2 + PROTO_MAX_PAYLOAD_SIZE];
			crc_buf[0] = rx_cmd; crc_buf[1] = rx_seq;
			memcpy(&crc_buf[2], rx_pkt, rx_len);
			uint16_t calc = crc16_ccitt(crc_buf, 2 + rx_len);
			if (calc == stored) {
				if (rx_cmd == CMD_ACK || rx_cmd == CMD_NACK) {
					/* ignore acks */
				} else {
					dispatch((proto_cmd_t)rx_cmd, rx_pkt, rx_len);
					/* Send ACK */
					uint8_t ack[PROTO_MIN_PACKET_SIZE + 1];
					int n = protocol_build_ack(ack, sizeof(ack), rx_seq, seq_no++);
					if (n > 0) uart_tx(dev, ack, (size_t)n, SYS_FOREVER_US);
				}
			} else {
				LOG_WRN("RX CRC mismatch");
				uint8_t nack[PROTO_MIN_PACKET_SIZE + 2];
				int n = protocol_build_nack(nack, sizeof(nack), rx_seq, seq_no++, NACK_CRC_ERROR);
				if (n > 0) uart_tx(dev, nack, (size_t)n, SYS_FOREVER_US);
			}
			rx_state = RX_WAIT_SOF;
			break;
		}
		default: rx_state = RX_WAIT_SOF; break;
		}
	}
}

static uint8_t rx_buf[UART_RX_BUF_SIZE];

int uart_bridge_init(void)
{
	uart_dev = DEVICE_DT_GET(UART_NODE);
	if (!device_is_ready(uart_dev)) {
		LOG_ERR("UART1 not ready");
		return -ENODEV;
	}
	uart_callback_set(uart_dev, uart_cb, NULL);
	uart_rx_enable(uart_dev, rx_buf, sizeof(rx_buf), UART_RX_TIMEOUT_MS * 1000);
	LOG_INF("UART bridge initialised at %lu bps", UART_BAUD_RATE);
	return 0;
}

int uart_bridge_send(proto_cmd_t cmd, const uint8_t *payload, uint16_t payload_len)
{
	uint8_t buf[PROTO_MAX_PACKET_SIZE];
	int n = protocol_encode(buf, sizeof(buf), cmd, seq_no++, payload, payload_len);
	if (n < 0) return n;
	return uart_tx(uart_dev, buf, (size_t)n, SYS_FOREVER_US);
}

void uart_bridge_register_callback(proto_cmd_t cmd, void (*cb)(const uint8_t *, uint16_t))
{
	if (num_cbs >= MAX_CBS) { LOG_ERR("CB table full"); return; }
	cbs[num_cbs].cmd = cmd;
	cbs[num_cbs].cb  = cb;
	num_cbs++;
}
