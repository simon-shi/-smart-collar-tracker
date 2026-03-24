/*
 * Copyright (c) 2024 Smart Pet Collar Tracker
 * SPDX-License-Identifier: Apache-2.0
 */

#ifndef FIRMWARE_NRF9160_CODEC_H_
#define FIRMWARE_NRF9160_CODEC_H_

#include <stdint.h>
#include <stddef.h>
#include "pet_data.h"

#ifdef __cplusplus
extern "C" {
#endif

/** Alert type codes used in codec_encode_alert(). */
typedef enum alert_type {
	ALERT_TYPE_GEOFENCE  = 1,
	ALERT_TYPE_LOW_BATT  = 2,
	ALERT_TYPE_FALL      = 3,
	ALERT_TYPE_INACTIVITY = 4,
	ALERT_TYPE_HEALTH    = 5,
} alert_type_t;

/** Command types decoded from incoming cloud JSON. */
typedef enum cmd_type {
	CMD_TYPE_SET_POWER_MODE   = 1,
	CMD_TYPE_FIND_PET         = 2,
	CMD_TYPE_LED_PATTERN      = 3,
	CMD_TYPE_ADD_GEOFENCE     = 4,
	CMD_TYPE_REMOVE_GEOFENCE  = 5,
	CMD_TYPE_SYNC_OFFLINE     = 6,
	CMD_TYPE_REBOOT           = 7,
	CMD_TYPE_CONFIG_UPDATE    = 8,
} cmd_type_t;

/** Activity summary passed into codec_encode_telemetry(). */
struct activity_summary {
	pet_activity_type_t dominant_activity;
	uint32_t            steps;
	uint32_t            calories_mcal;
};

/** Decoded inbound cloud command. */
struct collar_command {
	cmd_type_t type;
	union {
		uint8_t  power_mode;
		uint8_t  led_pattern;
		struct {
			uint8_t  id;
			double   lat;
			double   lon;
			uint32_t radius_m;
		} geofence;
	} param;
};

/**
 * @brief Encode a full telemetry JSON message.
 *
 * Output format:
 * {"ts":1711234567,"loc":{"lat":37.7749,"lon":-122.4194,"alt":10,"acc":5,"spd":1.2},
 *  "act":{"type":"walking","steps":1234,"cal":56},
 *  "bat":{"pct":85,"mv":3800,"charging":false},
 *  "sig":{"rsrp":-95,"rsrq":-10}}
 *
 * @param buf      Output buffer.
 * @param len      Buffer size.
 * @param loc      GPS fix (may be NULL – location fields omitted).
 * @param act      Activity summary.
 * @param bat      Battery status.
 * @param rsrp     RSRP in dBm.
 * @param rsrq     RSRQ in dB.
 *
 * @return Number of bytes written (excluding NUL), negative errno on error.
 */
int codec_encode_telemetry(char *buf, size_t len,
			   const pet_location_t *loc,
			   const struct activity_summary *act,
			   const battery_status_t *bat,
			   int rsrp, int rsrq);

/**
 * @brief Encode an alert JSON message.
 *
 * @param buf        Output buffer.
 * @param len        Buffer size.
 * @param alert_type Type of alert.
 * @param data       Alert-specific data pointer (type-dependent).
 *
 * @return Number of bytes written, negative errno on error.
 */
int codec_encode_alert(char *buf, size_t len,
		       alert_type_t alert_type, const void *data);

/**
 * @brief Decode an incoming cloud command from a JSON string.
 *
 * @param json_str  Input JSON string.
 * @param json_len  Length of json_str in bytes.
 * @param cmd_out   Populated on success.
 *
 * @return 0 on success, negative errno on failure.
 */
int codec_decode_command(const char *json_str, size_t json_len,
			 struct collar_command *cmd_out);

#ifdef __cplusplus
}
#endif

#endif /* FIRMWARE_NRF9160_CODEC_H_ */
