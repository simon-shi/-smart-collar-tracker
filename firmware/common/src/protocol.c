/*
 * Copyright (c) 2024 Smart Pet Collar Tracker
 * SPDX-License-Identifier: Apache-2.0
 *
 * Inter-chip UART protocol: encoding, decoding, and CRC16-CCITT helpers.
 *
 * Packet wire format (all multi-byte fields little-endian):
 *
 *   ┌────────┬───────────┬─────┬───────┬─────────────────┬──────────┐
 *   │  SOF   │  Length   │ Cmd │ SeqNo │     Payload     │  CRC16   │
 *   │ 1 byte │  2 bytes  │ 1 B │  1 B  │  0 – 512 bytes  │  2 bytes │
 *   │  0xAA  │    LE     │     │       │                 │    LE    │
 *   └────────┴───────────┴─────┴───────┴─────────────────┴──────────┘
 *
 * The CRC16-CCITT (poly 0x1021, init 0xFFFF) is computed over the
 * Cmd + SeqNo + Payload bytes (NOT over SOF or Length).
 */

#include "protocol.h"

#include <stddef.h>
#include <string.h>

/* -------------------------------------------------------------------------
 * CRC16-CCITT (polynomial 0x1021, initial value 0xFFFF)
 * ---------------------------------------------------------------------- */

/*
 * Pre-computed lookup table for CRC16-CCITT.
 *
 * Each entry crc16_table[i] is the CRC of the single-byte message i
 * (with initial value 0x0000 then XOR-folded to polynomial 0x1021).
 * This avoids inner-loop branching and speeds up byte-at-a-time processing.
 */
static const uint16_t crc16_table[256] = {
	0x0000, 0x1021, 0x2042, 0x3063, 0x4084, 0x50A5, 0x60C6, 0x70E7,
	0x8108, 0x9129, 0xA14A, 0xB16B, 0xC18C, 0xD1AD, 0xE1CE, 0xF1EF,
	0x1231, 0x0210, 0x3273, 0x2252, 0x52B5, 0x4294, 0x72F7, 0x62D6,
	0x9339, 0x8318, 0xB37B, 0xA35A, 0xD3BD, 0xC39C, 0xF3FF, 0xE3DE,
	0x2462, 0x3443, 0x0420, 0x1401, 0x64E6, 0x74C7, 0x44A4, 0x5485,
	0xA56A, 0xB54B, 0x8528, 0x9509, 0xE5EE, 0xF5CF, 0xC5AC, 0xD58D,
	0x3653, 0x2672, 0x1611, 0x0630, 0x76D7, 0x66F6, 0x5695, 0x46B4,
	0xB75B, 0xA77A, 0x9719, 0x8738, 0xF7DF, 0xE7FE, 0xD79D, 0xC7BC,
	0x48C4, 0x58E5, 0x6886, 0x78A7, 0x0840, 0x1861, 0x2802, 0x3823,
	0xC9CC, 0xD9ED, 0xE98E, 0xF9AF, 0x8948, 0x9969, 0xA90A, 0xB92B,
	0x5AF5, 0x4AD4, 0x7AB7, 0x6A96, 0x1A71, 0x0A50, 0x3A33, 0x2A12,
	0xDBFD, 0xCBDC, 0xFBBF, 0xEB9E, 0x9B79, 0x8B58, 0xBB3B, 0xAB1A,
	0x6CA6, 0x7C87, 0x4CE4, 0x5CC5, 0x2C22, 0x3C03, 0x0C60, 0x1C41,
	0xEDAE, 0xFD8F, 0xCDEC, 0xDDCD, 0xAD2A, 0xBD0B, 0x8D68, 0x9D49,
	0x7E97, 0x6EB6, 0x5ED5, 0x4EF4, 0x3E13, 0x2E32, 0x1E51, 0x0E70,
	0xFF9F, 0xEFBE, 0xDFDD, 0xCFFC, 0xBF1B, 0xAF3A, 0x9F59, 0x8F78,
	0x9188, 0x81A9, 0xB1CA, 0xA1EB, 0xD10C, 0xC12D, 0xF14E, 0xE16F,
	0x1080, 0x00A1, 0x30C2, 0x20E3, 0x5004, 0x4025, 0x7046, 0x6067,
	0x83B9, 0x9398, 0xA3FB, 0xB3DA, 0xC33D, 0xD31C, 0xE37F, 0xF35E,
	0x02B1, 0x1290, 0x22F3, 0x32D2, 0x4235, 0x5214, 0x6277, 0x7256,
	0xB5EA, 0xA5CB, 0x95A8, 0x8589, 0xF56E, 0xE54F, 0xD52C, 0xC50D,
	0x34E2, 0x24C3, 0x14A0, 0x0481, 0x7466, 0x6447, 0x5424, 0x4405,
	0xA7DB, 0xB7FA, 0x8799, 0x97B8, 0xE75F, 0xF77E, 0xC71D, 0xD73C,
	0x26D3, 0x36F2, 0x0691, 0x16B0, 0x6657, 0x7676, 0x4615, 0x5634,
	0xD94C, 0xC96D, 0xF90E, 0xE92F, 0x99C8, 0x89E9, 0xB98A, 0xA9AB,
	0x5844, 0x4865, 0x7806, 0x6827, 0x18C0, 0x08E1, 0x3882, 0x28A3,
	0xCB7D, 0xDB5C, 0xEB3F, 0xFB1E, 0x8BF9, 0x9BD8, 0xABBB, 0xBB9A,
	0x4A75, 0x5A54, 0x6A37, 0x7A16, 0x0AF1, 0x1AD0, 0x2AB3, 0x3A92,
	0xFD2E, 0xED0F, 0xDD6C, 0xCD4D, 0xBDAA, 0xAD8B, 0x9DE8, 0x8DC9,
	0x7C26, 0x6C07, 0x5C64, 0x4C45, 0x3CA2, 0x2C83, 0x1CE0, 0x0CC1,
	0xEF1F, 0xFF3E, 0xCF5D, 0xDF7C, 0xAF9B, 0xBFBA, 0x8FD9, 0x9FF8,
	0x6E17, 0x7E36, 0x4E55, 0x5E74, 0x2E93, 0x3EB2, 0x0ED1, 0x1EF0,
};

uint16_t crc16_ccitt_update(uint16_t crc, uint8_t byte)
{
	return (uint16_t)((crc << 8) ^ crc16_table[(crc >> 8) ^ byte]);
}

uint16_t crc16_ccitt(const uint8_t *data, size_t length)
{
	uint16_t crc = PROTO_CRC16_INIT;
	const uint8_t *end = data + length;

	while (data < end) {
		crc = crc16_ccitt_update(crc, *data++);
	}

	return crc;
}

/* -------------------------------------------------------------------------
 * Internal helpers
 * ---------------------------------------------------------------------- */

/** Write a uint16_t to buf in little-endian byte order. */
static inline void write_le16(uint8_t *buf, uint16_t val)
{
	buf[0] = (uint8_t)(val & 0xFFU);
	buf[1] = (uint8_t)((val >> 8) & 0xFFU);
}

/** Read a uint16_t from buf in little-endian byte order. */
static inline uint16_t read_le16(const uint8_t *buf)
{
	return (uint16_t)((uint16_t)buf[0] | ((uint16_t)buf[1] << 8));
}

/* -------------------------------------------------------------------------
 * Encode
 * ---------------------------------------------------------------------- */

int protocol_encode(uint8_t *buf, size_t buf_size,
		    proto_cmd_t cmd, uint8_t seq_no,
		    const uint8_t *payload, uint16_t payload_len)
{
	if (buf == NULL) {
		return PROTO_ERR_NULL_PTR;
	}

	if (payload_len > PROTO_MAX_PAYLOAD_SIZE) {
		return PROTO_ERR_PAYLOAD_TOO_BIG;
	}

	if (payload == NULL && payload_len > 0U) {
		return PROTO_ERR_NULL_PTR;
	}

	size_t total_len = (size_t)PROTO_MIN_PACKET_SIZE + (size_t)payload_len;

	if (buf_size < total_len) {
		return PROTO_ERR_BUF_TOO_SMALL;
	}

	/* SOF */
	buf[PROTO_OFFSET_SOF] = PROTO_SOF;

	/* Length (payload length, LE) */
	write_le16(&buf[PROTO_OFFSET_LENGTH_LO], payload_len);

	/* Cmd */
	buf[PROTO_OFFSET_CMD] = (uint8_t)cmd;

	/* SeqNo */
	buf[PROTO_OFFSET_SEQNO] = seq_no;

	/* Payload */
	if (payload_len > 0U) {
		(void)memcpy(&buf[PROTO_OFFSET_PAYLOAD], payload, payload_len);
	}

	/* CRC16-CCITT over Cmd + SeqNo + Payload */
	uint16_t crc = PROTO_CRC16_INIT;

	crc = crc16_ccitt_update(crc, (uint8_t)cmd);
	crc = crc16_ccitt_update(crc, seq_no);

	for (uint16_t i = 0U; i < payload_len; i++) {
		crc = crc16_ccitt_update(crc, payload[i]);
	}

	/* CRC (LE), appended after payload */
	write_le16(&buf[PROTO_OFFSET_PAYLOAD + payload_len], crc);

	return (int)total_len;
}

/* -------------------------------------------------------------------------
 * Decode
 * ---------------------------------------------------------------------- */

int protocol_decode(const uint8_t *buf, size_t buf_len,
		    proto_packet_t *packet)
{
	if (buf == NULL || packet == NULL) {
		return PROTO_ERR_NULL_PTR;
	}

	/* Minimum length check before accessing any field. */
	if (buf_len < PROTO_MIN_PACKET_SIZE) {
		return PROTO_ERR_INVALID_LENGTH;
	}

	/* Validate SOF. */
	if (buf[PROTO_OFFSET_SOF] != PROTO_SOF) {
		return PROTO_ERR_INVALID_SOF;
	}

	/* Extract and validate payload length. */
	uint16_t payload_len = read_le16(&buf[PROTO_OFFSET_LENGTH_LO]);

	if (payload_len > PROTO_MAX_PAYLOAD_SIZE) {
		return PROTO_ERR_PAYLOAD_TOO_BIG;
	}

	size_t expected_total = (size_t)PROTO_MIN_PACKET_SIZE + (size_t)payload_len;

	if (buf_len < expected_total) {
		return PROTO_ERR_INVALID_LENGTH;
	}

	/* Extract Cmd and SeqNo. */
	proto_cmd_t cmd    = (proto_cmd_t)buf[PROTO_OFFSET_CMD];
	uint8_t     seq_no = buf[PROTO_OFFSET_SEQNO];

	/* Compute expected CRC over Cmd + SeqNo + Payload. */
	uint16_t crc = PROTO_CRC16_INIT;

	crc = crc16_ccitt_update(crc, (uint8_t)cmd);
	crc = crc16_ccitt_update(crc, seq_no);

	for (uint16_t i = 0U; i < payload_len; i++) {
		crc = crc16_ccitt_update(crc, buf[PROTO_OFFSET_PAYLOAD + i]);
	}

	/* Read received CRC (LE). */
	uint16_t received_crc = read_le16(
		&buf[PROTO_OFFSET_PAYLOAD + payload_len]);

	if (crc != received_crc) {
		return PROTO_ERR_CRC_MISMATCH;
	}

	/* Populate output structure. */
	packet->cmd         = cmd;
	packet->seq_no      = seq_no;
	packet->payload_len = payload_len;
	packet->payload     = (payload_len > 0U)
				? &buf[PROTO_OFFSET_PAYLOAD]
				: NULL;

	return PROTO_OK;
}

/* -------------------------------------------------------------------------
 * Convenience helpers
 * ---------------------------------------------------------------------- */

uint8_t protocol_get_cmd(const uint8_t *buf, size_t buf_len)
{
	if (buf == NULL || buf_len < PROTO_MIN_PACKET_SIZE) {
		return 0U;
	}
	return buf[PROTO_OFFSET_CMD];
}

const uint8_t *protocol_get_payload(const uint8_t *buf, size_t buf_len)
{
	if (buf == NULL || buf_len < PROTO_MIN_PACKET_SIZE) {
		return NULL;
	}
	return &buf[PROTO_OFFSET_PAYLOAD];
}

int protocol_build_ack(uint8_t *buf, size_t buf_size,
		       uint8_t seq_no, uint8_t ack_seq)
{
	/*
	 * ACK payload: 1 byte carrying the sequence number being acknowledged.
	 */
	return protocol_encode(buf, buf_size, CMD_ACK, ack_seq,
			       &seq_no, sizeof(seq_no));
}

int protocol_build_nack(uint8_t *buf, size_t buf_size,
			uint8_t seq_no, uint8_t ack_seq,
			proto_nack_reason_t reason)
{
	/*
	 * NACK payload: 2 bytes.
	 *   byte 0: sequence number of the offending packet.
	 *   byte 1: reason code (proto_nack_reason_t).
	 */
	uint8_t nack_payload[2] = {
		seq_no,
		(uint8_t)reason,
	};

	return protocol_encode(buf, buf_size, CMD_NACK, ack_seq,
			       nack_payload, sizeof(nack_payload));
}
