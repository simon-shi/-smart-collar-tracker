/*
 * Copyright (c) 2024 Smart Pet Collar Tracker
 * SPDX-License-Identifier: Apache-2.0
 *
 * Inter-chip UART protocol definition.
 *
 * Packet format (all multi-byte fields little-endian):
 *   SOF    : 1 byte  = 0xAA
 *   Length : 2 bytes = payload length (0–512)
 *   Cmd    : 1 byte  = command identifier
 *   SeqNo  : 1 byte  = sequence number (wraps 0–255)
 *   Payload: 0–512 bytes
 *   CRC16  : 2 bytes = CRC16-CCITT over Cmd+SeqNo+Payload
 */

#ifndef FIRMWARE_COMMON_PROTOCOL_H_
#define FIRMWARE_COMMON_PROTOCOL_H_

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/* -------------------------------------------------------------------------
 * Protocol constants
 * ---------------------------------------------------------------------- */

/** Start-of-frame marker. */
#define PROTO_SOF               0xAAU

/** Maximum payload size in bytes. */
#define PROTO_MAX_PAYLOAD_SIZE  512U

/**
 * Minimum encoded packet size:
 *   SOF(1) + Length(2) + Cmd(1) + SeqNo(1) + CRC16(2) = 7 bytes.
 */
#define PROTO_MIN_PACKET_SIZE   7U

/**
 * Maximum encoded packet size:
 *   PROTO_MIN_PACKET_SIZE + PROTO_MAX_PAYLOAD_SIZE.
 */
#define PROTO_MAX_PACKET_SIZE   (PROTO_MIN_PACKET_SIZE + PROTO_MAX_PAYLOAD_SIZE)

/* Byte offsets within an encoded packet buffer. */
#define PROTO_OFFSET_SOF        0U
#define PROTO_OFFSET_LENGTH_LO  1U
#define PROTO_OFFSET_LENGTH_HI  2U
#define PROTO_OFFSET_CMD        3U
#define PROTO_OFFSET_SEQNO      4U
#define PROTO_OFFSET_PAYLOAD    5U

/* CRC16-CCITT parameters. */
#define PROTO_CRC16_POLY        0x1021U
#define PROTO_CRC16_INIT        0xFFFFU

/* -------------------------------------------------------------------------
 * Command identifiers
 * ---------------------------------------------------------------------- */

typedef enum proto_cmd {
	CMD_GPS_DATA       = 0x01, /**< GPS fix data from MCU → nRF9160.       */
	CMD_ACTIVITY_DATA  = 0x02, /**< Accelerometer activity summary.         */
	CMD_GEOFENCE_ALERT = 0x03, /**< Geofence breach notification.           */
	CMD_LED_CONTROL    = 0x04, /**< LED colour/pattern command.             */
	CMD_FIND_PET       = 0x05, /**< Audible/visual find-pet trigger.        */
	CMD_CONFIG_SYNC    = 0x06, /**< Configuration parameter synchronisation.*/
	CMD_STATUS_REQ     = 0x07, /**< Status request (no payload).            */
	CMD_STATUS_RESP    = 0x08, /**< Status response payload.                */
	CMD_DFU_DATA       = 0x09, /**< DFU firmware block transfer.            */
	CMD_POWER_MODE     = 0x0A, /**< Power-mode change request/notification. */
	CMD_OFFLINE_SYNC   = 0x0B, /**< Offline track-log synchronisation.      */
	CMD_HEALTH_DATA    = 0x0C, /**< Pet health sensor data.                 */
	CMD_ACK            = 0xFE, /**< Positive acknowledgement.               */
	CMD_NACK           = 0xFF, /**< Negative acknowledgement / error.       */
} proto_cmd_t;

/* -------------------------------------------------------------------------
 * NACK reason codes (carried in the first payload byte of CMD_NACK)
 * ---------------------------------------------------------------------- */

typedef enum proto_nack_reason {
	NACK_UNKNOWN_CMD    = 0x01,
	NACK_INVALID_LEN    = 0x02,
	NACK_CRC_ERROR      = 0x03,
	NACK_BUSY           = 0x04,
	NACK_INVALID_PARAM  = 0x05,
} proto_nack_reason_t;

/* -------------------------------------------------------------------------
 * Packet structure (decoded view)
 * ---------------------------------------------------------------------- */

/**
 * @brief Decoded inter-chip protocol packet.
 *
 * Populated by protocol_decode(); consumed by protocol_encode().
 * The @p payload field points into the caller-supplied buffer – it is
 * NOT heap-allocated and must not be freed.
 */
typedef struct proto_packet {
	proto_cmd_t  cmd;                            /**< Command identifier.      */
	uint8_t      seq_no;                         /**< Sequence number 0–255.   */
	uint16_t     payload_len;                    /**< Number of payload bytes. */
	const uint8_t *payload;                      /**< Pointer into rx buffer.  */
} proto_packet_t;

/* -------------------------------------------------------------------------
 * Return codes
 * ---------------------------------------------------------------------- */

#define PROTO_OK                  0   /**< Success.                          */
#define PROTO_ERR_NULL_PTR       -1   /**< A required pointer was NULL.      */
#define PROTO_ERR_INVALID_SOF    -2   /**< SOF byte mismatch.                */
#define PROTO_ERR_PAYLOAD_TOO_BIG -3  /**< Payload exceeds max size.         */
#define PROTO_ERR_BUF_TOO_SMALL  -4   /**< Output buffer too small.          */
#define PROTO_ERR_CRC_MISMATCH   -5   /**< CRC16 verification failed.        */
#define PROTO_ERR_INVALID_LENGTH -6   /**< Length field inconsistent.        */

/* -------------------------------------------------------------------------
 * CRC16-CCITT (polynomial 0x1021, initial value 0xFFFF)
 * ---------------------------------------------------------------------- */

/**
 * @brief Compute CRC16-CCITT over a data buffer.
 *
 * @param data    Pointer to input data.
 * @param length  Number of bytes to process.
 *
 * @return 16-bit CRC value.
 */
uint16_t crc16_ccitt(const uint8_t *data, size_t length);

/**
 * @brief Update a running CRC16-CCITT value with one additional byte.
 *
 * Useful for incremental (streaming) CRC computation.
 *
 * @param crc   Current CRC accumulator (initialise to PROTO_CRC16_INIT).
 * @param byte  Next byte to process.
 *
 * @return Updated CRC value.
 */
uint16_t crc16_ccitt_update(uint16_t crc, uint8_t byte);

/* -------------------------------------------------------------------------
 * Encode / decode API
 * ---------------------------------------------------------------------- */

/**
 * @brief Encode a packet into a flat byte buffer ready for transmission.
 *
 * The CRC is computed over the Cmd, SeqNo, and Payload fields.
 * Multi-byte fields are encoded little-endian.
 *
 * @param[out] buf         Destination buffer (at least
 *                         PROTO_MIN_PACKET_SIZE + payload_len bytes).
 * @param[in]  buf_size    Size of @p buf in bytes.
 * @param[in]  cmd         Command identifier.
 * @param[in]  seq_no      Sequence number.
 * @param[in]  payload     Payload bytes (may be NULL when payload_len == 0).
 * @param[in]  payload_len Number of payload bytes (0–PROTO_MAX_PAYLOAD_SIZE).
 *
 * @retval >0              Total encoded packet length in bytes.
 * @retval PROTO_ERR_*     Negative error code on failure.
 */
int protocol_encode(uint8_t *buf, size_t buf_size,
		    proto_cmd_t cmd, uint8_t seq_no,
		    const uint8_t *payload, uint16_t payload_len);

/**
 * @brief Decode a flat byte buffer into a proto_packet_t.
 *
 * Validates SOF, length field consistency, and CRC16.  The @p packet->payload
 * field is set to point directly into @p buf (zero-copy).
 *
 * @param[in]  buf      Source buffer containing a complete encoded packet.
 * @param[in]  buf_len  Number of valid bytes in @p buf.
 * @param[out] packet   Caller-supplied structure to populate.
 *
 * @retval PROTO_OK     Success.
 * @retval PROTO_ERR_*  Negative error code on failure.
 */
int protocol_decode(const uint8_t *buf, size_t buf_len,
		    proto_packet_t *packet);

/* -------------------------------------------------------------------------
 * Convenience helpers
 * ---------------------------------------------------------------------- */

/**
 * @brief Extract the command byte from an encoded packet buffer.
 *
 * Does not validate the full packet – use only after a length pre-check.
 *
 * @param buf     Pointer to the start of an encoded packet.
 * @param buf_len Length of available data in @p buf.
 *
 * @return Command byte, or 0 if @p buf is NULL or too short.
 */
uint8_t protocol_get_cmd(const uint8_t *buf, size_t buf_len);

/**
 * @brief Return a pointer to the payload region of an encoded packet buffer.
 *
 * Does not validate the full packet.
 *
 * @param buf     Pointer to the start of an encoded packet.
 * @param buf_len Length of available data in @p buf.
 *
 * @return Pointer to the payload start, or NULL if @p buf is too short.
 */
const uint8_t *protocol_get_payload(const uint8_t *buf, size_t buf_len);

/**
 * @brief Build a minimal ACK packet for a received sequence number.
 *
 * The payload of an ACK is a single byte containing the seq_no being
 * acknowledged.
 *
 * @param[out] buf      Destination buffer (>= PROTO_MIN_PACKET_SIZE + 1).
 * @param[in]  buf_size Size of @p buf.
 * @param[in]  seq_no   Sequence number to acknowledge.
 * @param[in]  ack_seq  Sequence number to assign to the ACK packet itself.
 *
 * @retval >0           Encoded packet length.
 * @retval PROTO_ERR_*  Negative error code on failure.
 */
int protocol_build_ack(uint8_t *buf, size_t buf_size,
		       uint8_t seq_no, uint8_t ack_seq);

/**
 * @brief Build a NACK packet carrying a reason code.
 *
 * @param[out] buf      Destination buffer (>= PROTO_MIN_PACKET_SIZE + 2).
 * @param[in]  buf_size Size of @p buf.
 * @param[in]  seq_no   Sequence number of the offending packet.
 * @param[in]  ack_seq  Sequence number to assign to the NACK packet itself.
 * @param[in]  reason   NACK reason code.
 *
 * @retval >0           Encoded packet length.
 * @retval PROTO_ERR_*  Negative error code on failure.
 */
int protocol_build_nack(uint8_t *buf, size_t buf_size,
			uint8_t seq_no, uint8_t ack_seq,
			proto_nack_reason_t reason);

#ifdef __cplusplus
}
#endif

#endif /* FIRMWARE_COMMON_PROTOCOL_H_ */
