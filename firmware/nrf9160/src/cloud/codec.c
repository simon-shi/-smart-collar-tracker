/*
 * Copyright (c) 2024 Smart Pet Collar Tracker
 * SPDX-License-Identifier: Apache-2.0
 *
 * JSON codec for telemetry, alerts, and inbound commands using
 * Zephyr's built-in JSON library (zephyr/data/json.h).
 */

#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>
#include <zephyr/data/json.h>
#include <stdio.h>
#include <string.h>
#include <math.h>

#include "codec.h"
#include "config.h"

LOG_MODULE_REGISTER(codec, LOG_LEVEL_DBG);

/* ── Activity type name lookup ──────────────────────────────────────────*/
static const char *activity_name(pet_activity_type_t t)
{
	switch (t) {
	case ACT_REST:  return "resting";
	case ACT_WALK:  return "walking";
	case ACT_RUN:   return "running";
	case ACT_PLAY:  return "playing";
	case ACT_SWIM:  return "swimming";
	case ACT_SLEEP: return "sleeping";
	default:        return "unknown";
	}
}

/* ── Telemetry encode ───────────────────────────────────────────────────*/

int codec_encode_telemetry(char *buf, size_t len,
			   const pet_location_t *loc,
			   const struct activity_summary *act,
			   const battery_status_t *bat,
			   int rsrp, int rsrq)
{
	if (!buf || len == 0 || !act || !bat) {
		return -EINVAL;
	}

	int n = 0;

	/* Timestamp */
	uint32_t ts = bat->timestamp_s; /* use battery timestamp as base */
	if (loc && loc->timestamp_s != 0) {
		ts = loc->timestamp_s;
	}

	n += snprintf(buf + n, len - (size_t)n,
		      "{\"ts\":%u", ts);

	/* Location */
	if (loc && loc->fix_quality != 0) {
		double lat = (double)loc->latitude_udeg  / 1e6;
		double lon = (double)loc->longitude_udeg / 1e6;
		double alt = (double)loc->altitude_mm    / 1000.0;
		double acc = (double)loc->accuracy_mm    / 1000.0;
		double spd = (double)loc->speed_mmps     / 1000.0;

		n += snprintf(buf + n, len - (size_t)n,
			      ",\"loc\":{\"lat\":%.6f,\"lon\":%.6f"
			      ",\"alt\":%.1f,\"acc\":%.1f,\"spd\":%.2f"
			      ",\"hdg\":%.1f,\"sat\":%u,\"q\":%u}",
			      lat, lon, alt, acc, spd,
			      (double)loc->heading_cdeg / 100.0,
			      (unsigned)loc->satellites,
			      (unsigned)loc->fix_quality);
	}

	/* Activity */
	double cal = (double)act->calories_mcal / 1000.0;
	n += snprintf(buf + n, len - (size_t)n,
		      ",\"act\":{\"type\":\"%s\",\"steps\":%u,\"cal\":%.1f}",
		      activity_name(act->dominant_activity),
		      (unsigned)act->steps,
		      cal);

	/* Battery */
	n += snprintf(buf + n, len - (size_t)n,
		      ",\"bat\":{\"pct\":%u,\"mv\":%u,\"charging\":%s}",
		      (unsigned)bat->percent,
		      (unsigned)bat->millivolts,
		      bat->is_charging ? "true" : "false");

	/* Signal */
	n += snprintf(buf + n, len - (size_t)n,
		      ",\"sig\":{\"rsrp\":%d,\"rsrq\":%d}}",
		      rsrp, rsrq);

	if (n < 0 || (size_t)n >= len) {
		LOG_ERR("Telemetry buffer overflow: need %d, have %zu", n, len);
		return -ENOSPC;
	}

	LOG_DBG("Telemetry encoded: %d bytes", n);
	return n;
}

/* ── Alert encode ───────────────────────────────────────────────────────*/

int codec_encode_alert(char *buf, size_t len,
		       alert_type_t alert_type, const void *data)
{
	if (!buf || len == 0) {
		return -EINVAL;
	}

	int n = 0;
	const char *type_str;

	switch (alert_type) {
	case ALERT_TYPE_GEOFENCE:   type_str = "geofence";   break;
	case ALERT_TYPE_LOW_BATT:   type_str = "low_battery"; break;
	case ALERT_TYPE_FALL:       type_str = "fall";        break;
	case ALERT_TYPE_INACTIVITY: type_str = "inactivity";  break;
	case ALERT_TYPE_HEALTH:     type_str = "health";      break;
	default:                    type_str = "unknown";     break;
	}

	n = snprintf(buf, len, "{\"alert\":\"%s\"", type_str);

	if (alert_type == ALERT_TYPE_GEOFENCE && data) {
		const geofence_alert_t *ga = (const geofence_alert_t *)data;
		double lat = (double)ga->location.latitude_udeg  / 1e6;
		double lon = (double)ga->location.longitude_udeg / 1e6;

		n += snprintf(buf + n, len - (size_t)n,
			      ",\"fence_id\":%u,\"event\":\"%s\""
			      ",\"ts\":%u"
			      ",\"loc\":{\"lat\":%.6f,\"lon\":%.6f}",
			      (unsigned)ga->fence_id,
			      ga->breach_type == BREACH_EXIT ? "exit" : "enter",
			      ga->timestamp_s, lat, lon);
	}

	n += snprintf(buf + n, len - (size_t)n, "}");

	if (n < 0 || (size_t)n >= len) {
		return -ENOSPC;
	}

	return n;
}

/* ── Command decode ─────────────────────────────────────────────────────*/

/* Minimal hand-rolled JSON field extractor (avoids heap allocation).
 * Searches for key in a flat JSON object and returns the value string.
 * Returns NULL if key is not found. */
static const char *find_json_value(const char *json, const char *key,
				   char *val_buf, size_t val_buf_sz)
{
	char search[64];
	snprintf(search, sizeof(search), "\"%s\"", key);

	const char *p = strstr(json, search);
	if (!p) {
		return NULL;
	}
	p += strlen(search);

	/* Skip whitespace and colon */
	while (*p == ' ' || *p == '\t' || *p == ':') {
		p++;
	}

	size_t i = 0;
	bool   in_str = false;

	if (*p == '"') {
		in_str = true;
		p++;
	}

	while (*p && i < val_buf_sz - 1) {
		if (in_str) {
			if (*p == '"') {
				break;
			}
		} else {
			if (*p == ',' || *p == '}' || *p == ' ') {
				break;
			}
		}
		val_buf[i++] = *p++;
	}
	val_buf[i] = '\0';
	return val_buf;
}

int codec_decode_command(const char *json_str, size_t json_len,
			 struct collar_command *cmd_out)
{
	if (!json_str || !cmd_out || json_len == 0) {
		return -EINVAL;
	}

	char val[64];

	/* "type" field is mandatory */
	if (!find_json_value(json_str, "type", val, sizeof(val))) {
		LOG_ERR("Command missing 'type' field");
		return -EINVAL;
	}

	memset(cmd_out, 0, sizeof(*cmd_out));

	if (strcmp(val, "set_power_mode") == 0) {
		cmd_out->type = CMD_TYPE_SET_POWER_MODE;
		char mode_s[16];
		find_json_value(json_str, "mode", mode_s, sizeof(mode_s));
		if      (strcmp(mode_s, "deep_sleep") == 0) cmd_out->param.power_mode = PWR_DEEP_SLEEP;
		else if (strcmp(mode_s, "low_power")  == 0) cmd_out->param.power_mode = PWR_LOW_POWER;
		else if (strcmp(mode_s, "active")     == 0) cmd_out->param.power_mode = PWR_ACTIVE;
		else if (strcmp(mode_s, "tracking")   == 0) cmd_out->param.power_mode = PWR_TRACKING;
		else {
			LOG_ERR("Unknown power mode: %s", mode_s);
			return -EINVAL;
		}
	} else if (strcmp(val, "find_pet") == 0) {
		cmd_out->type = CMD_TYPE_FIND_PET;
	} else if (strcmp(val, "led_pattern") == 0) {
		cmd_out->type = CMD_TYPE_LED_PATTERN;
		char pat_s[16];
		find_json_value(json_str, "pattern", pat_s, sizeof(pat_s));
		cmd_out->param.led_pattern = (uint8_t)atoi(pat_s);
	} else if (strcmp(val, "add_geofence") == 0) {
		cmd_out->type = CMD_TYPE_ADD_GEOFENCE;
		char tmp[32];
		find_json_value(json_str, "id",  tmp, sizeof(tmp));
		cmd_out->param.geofence.id = (uint8_t)atoi(tmp);
		find_json_value(json_str, "lat", tmp, sizeof(tmp));
		cmd_out->param.geofence.lat = atof(tmp);
		find_json_value(json_str, "lon", tmp, sizeof(tmp));
		cmd_out->param.geofence.lon = atof(tmp);
		find_json_value(json_str, "radius", tmp, sizeof(tmp));
		cmd_out->param.geofence.radius_m = (uint32_t)atoi(tmp);
	} else if (strcmp(val, "remove_geofence") == 0) {
		cmd_out->type = CMD_TYPE_REMOVE_GEOFENCE;
		find_json_value(json_str, "id", val, sizeof(val));
		cmd_out->param.geofence.id = (uint8_t)atoi(val);
	} else if (strcmp(val, "sync_offline") == 0) {
		cmd_out->type = CMD_TYPE_SYNC_OFFLINE;
	} else if (strcmp(val, "reboot") == 0) {
		cmd_out->type = CMD_TYPE_REBOOT;
	} else {
		LOG_WRN("Unknown command type: %s", val);
		return -ENOTSUP;
	}

	LOG_DBG("Decoded command type=%d", cmd_out->type);
	return 0;
}
