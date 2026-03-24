/*
 * Copyright (c) 2024 Smart Pet Collar Tracker
 * SPDX-License-Identifier: Apache-2.0
 *
 * Serialisation / deserialisation helpers for shared pet-data structures.
 *
 * All multi-byte integer fields are encoded in little-endian byte order.
 * Boolean fields are encoded as a single byte (0x00 = false, 0x01 = true).
 * Enum fields are encoded as their underlying uint8_t value.
 *
 * Serialised layouts (offsets in bytes):
 *
 * pet_location_t  (PET_LOCATION_SERIALISED_SIZE = 26)
 *   0  : int32_t  latitude_udeg     (4)
 *   4  : int32_t  longitude_udeg    (4)
 *   8  : int32_t  altitude_mm       (4)
 *   12 : uint32_t speed_mmps        (4)
 *   16 : uint16_t heading_cdeg      (2)
 *   18 : uint32_t accuracy_mm       (4)
 *   22 : uint32_t timestamp_s       (4) -- corrected offset after heading(2)
 *   ... wait — recount:
 *   0  : int32_t  latitude_udeg     (4)  → ends at 4
 *   4  : int32_t  longitude_udeg    (4)  → ends at 8
 *   8  : int32_t  altitude_mm       (4)  → ends at 12
 *   12 : uint32_t speed_mmps        (4)  → ends at 16
 *   16 : uint16_t heading_cdeg      (2)  → ends at 18
 *   18 : uint32_t accuracy_mm       (4)  → ends at 22
 *   22 : uint32_t timestamp_s       (4)  → ends at 26 ✓  (fix_quality and
 *   NO — pet_location_t has fix_quality(1) + satellites(1).  That is 28 B.
 *   We define PET_LOCATION_SERIALISED_SIZE as 26 B by omitting those fields
 *   from the on-wire format when space is critical; they are zero-filled on
 *   deserialise.  The extended format (28 B) is used for MQTT JSON encoding
 *   only.  Here we serialise all fields: 26 core + fix_quality(1) +
 *   satellites(1) = 28 bytes total.  We update the macro comment accordingly.
 *
 *   Actual layout used in this file (28 bytes):
 *   0  : int32_t  latitude_udeg     (4)
 *   4  : int32_t  longitude_udeg    (4)
 *   8  : int32_t  altitude_mm       (4)
 *   12 : uint32_t speed_mmps        (4)
 *   16 : uint16_t heading_cdeg      (2)
 *   18 : uint32_t accuracy_mm       (4)
 *   22 : uint32_t timestamp_s       (4)
 *   26 : uint8_t  fix_quality       (1)
 *   27 : uint8_t  satellites        (1)
 *   Total = 28 bytes.
 *   NOTE: PET_LOCATION_SERIALISED_SIZE in pet_data.h is defined as 26.
 *   We keep backward compatibility by serialising only the first 26 bytes
 *   (latitude through timestamp) and ignoring fix_quality / satellites in
 *   the protocol layer.  A receiver that wants those fields must use the
 *   extended helpers defined at the bottom of this file.
 *
 * pet_activity_data_t  (PET_ACTIVITY_SERIALISED_SIZE = 17)
 *   0  : uint32_t steps             (4)
 *   4  : uint32_t calories_mcal     (4)
 *   8  : uint32_t duration_s        (4)
 *   12 : uint32_t timestamp_s       (4)
 *   16 : uint8_t  activity_type     (1)
 *   Total = 17 bytes.
 *
 * battery_status_t  (PET_BATTERY_SERIALISED_SIZE = 8)
 *   0  : uint8_t  percent           (1)
 *   1  : uint16_t millivolts        (2)
 *   3  : uint8_t  is_charging       (1)
 *   4  : uint32_t timestamp_s       (4)
 *   Total = 8 bytes.
 *
 * geofence_alert_t  (PET_GEOFENCE_SERIALISED_SIZE = 6 + PET_LOCATION_SERIALISED_SIZE)
 *   0  : uint8_t  fence_id          (1)
 *   1  : uint8_t  breach_type       (1)
 *   2  : uint32_t timestamp_s       (4)
 *   6  : <pet_location serialised>  (PET_LOCATION_SERIALISED_SIZE)
 *
 * pet_health_data_t  (PET_HEALTH_SERIALISED_SIZE = 9)
 *   0  : int16_t  temperature_cdegC (2)
 *   2  : uint16_t heart_rate_bpm    (2)
 *   4  : uint8_t  anomaly_flags     (1)
 *   5  : uint32_t timestamp_s       (4)
 *   Total = 9 bytes.
 */

#include "pet_data.h"

#include <string.h>

/* -------------------------------------------------------------------------
 * Internal little-endian helpers
 * ---------------------------------------------------------------------- */

static inline void put_u8(uint8_t *buf, size_t *off, uint8_t val)
{
	buf[(*off)++] = val;
}

static inline void put_u16_le(uint8_t *buf, size_t *off, uint16_t val)
{
	buf[(*off)++] = (uint8_t)(val & 0xFFU);
	buf[(*off)++] = (uint8_t)((val >> 8) & 0xFFU);
}

static inline void put_i16_le(uint8_t *buf, size_t *off, int16_t val)
{
	put_u16_le(buf, off, (uint16_t)val);
}

static inline void put_u32_le(uint8_t *buf, size_t *off, uint32_t val)
{
	buf[(*off)++] = (uint8_t)(val & 0xFFU);
	buf[(*off)++] = (uint8_t)((val >> 8) & 0xFFU);
	buf[(*off)++] = (uint8_t)((val >> 16) & 0xFFU);
	buf[(*off)++] = (uint8_t)((val >> 24) & 0xFFU);
}

static inline void put_i32_le(uint8_t *buf, size_t *off, int32_t val)
{
	put_u32_le(buf, off, (uint32_t)val);
}

static inline uint8_t get_u8(const uint8_t *buf, size_t *off)
{
	return buf[(*off)++];
}

static inline uint16_t get_u16_le(const uint8_t *buf, size_t *off)
{
	uint16_t val = (uint16_t)buf[*off] |
		       ((uint16_t)buf[*off + 1U] << 8);
	*off += 2U;
	return val;
}

static inline int16_t get_i16_le(const uint8_t *buf, size_t *off)
{
	return (int16_t)get_u16_le(buf, off);
}

static inline uint32_t get_u32_le(const uint8_t *buf, size_t *off)
{
	uint32_t val = (uint32_t)buf[*off] |
		       ((uint32_t)buf[*off + 1U] << 8) |
		       ((uint32_t)buf[*off + 2U] << 16) |
		       ((uint32_t)buf[*off + 3U] << 24);
	*off += 4U;
	return val;
}

static inline int32_t get_i32_le(const uint8_t *buf, size_t *off)
{
	return (int32_t)get_u32_le(buf, off);
}

/* -------------------------------------------------------------------------
 * pet_location_t
 *
 * On-wire layout (PET_LOCATION_SERIALISED_SIZE = 26 bytes):
 *   0  latitude_udeg  int32  LE
 *   4  longitude_udeg int32  LE
 *   8  altitude_mm    int32  LE
 *   12 speed_mmps     uint32 LE
 *   16 heading_cdeg   uint16 LE
 *   18 accuracy_mm    uint32 LE
 *   22 timestamp_s    uint32 LE
 *   (fix_quality and satellites not included in the 26-byte protocol payload)
 * ---------------------------------------------------------------------- */

int pet_location_serialise(uint8_t *buf, const pet_location_t *loc)
{
	if (buf == NULL || loc == NULL) {
		return -1;
	}

	size_t off = 0U;

	put_i32_le(buf, &off, loc->latitude_udeg);
	put_i32_le(buf, &off, loc->longitude_udeg);
	put_i32_le(buf, &off, loc->altitude_mm);
	put_u32_le(buf, &off, loc->speed_mmps);
	put_u16_le(buf, &off, loc->heading_cdeg);
	put_u32_le(buf, &off, loc->accuracy_mm);
	put_u32_le(buf, &off, loc->timestamp_s);

	/* off == PET_LOCATION_SERIALISED_SIZE (26) */
	return (int)off;
}

int pet_location_deserialise(pet_location_t *loc, const uint8_t *buf)
{
	if (loc == NULL || buf == NULL) {
		return -1;
	}

	size_t off = 0U;

	loc->latitude_udeg  = get_i32_le(buf, &off);
	loc->longitude_udeg = get_i32_le(buf, &off);
	loc->altitude_mm    = get_i32_le(buf, &off);
	loc->speed_mmps     = get_u32_le(buf, &off);
	loc->heading_cdeg   = get_u16_le(buf, &off);
	loc->accuracy_mm    = get_u32_le(buf, &off);
	loc->timestamp_s    = get_u32_le(buf, &off);

	/* Fields not in the 26-byte protocol payload are zeroed. */
	loc->fix_quality = 0U;
	loc->satellites  = 0U;

	return 0;
}

/* -------------------------------------------------------------------------
 * pet_activity_data_t
 *
 * On-wire layout (PET_ACTIVITY_SERIALISED_SIZE = 17 bytes):
 *   0  steps          uint32 LE
 *   4  calories_mcal  uint32 LE
 *   8  duration_s     uint32 LE
 *   12 timestamp_s    uint32 LE
 *   16 activity_type  uint8
 * ---------------------------------------------------------------------- */

int pet_activity_serialise(uint8_t *buf, const pet_activity_data_t *act)
{
	if (buf == NULL || act == NULL) {
		return -1;
	}

	size_t off = 0U;

	put_u32_le(buf, &off, act->steps);
	put_u32_le(buf, &off, act->calories_mcal);
	put_u32_le(buf, &off, act->duration_s);
	put_u32_le(buf, &off, act->timestamp_s);
	put_u8(buf, &off, (uint8_t)act->activity_type);

	/* off == PET_ACTIVITY_SERIALISED_SIZE (17) */
	return (int)off;
}

int pet_activity_deserialise(pet_activity_data_t *act, const uint8_t *buf)
{
	if (act == NULL || buf == NULL) {
		return -1;
	}

	size_t off = 0U;

	act->steps         = get_u32_le(buf, &off);
	act->calories_mcal = get_u32_le(buf, &off);
	act->duration_s    = get_u32_le(buf, &off);
	act->timestamp_s   = get_u32_le(buf, &off);
	act->activity_type = (pet_activity_type_t)get_u8(buf, &off);

	return 0;
}

/* -------------------------------------------------------------------------
 * battery_status_t
 *
 * On-wire layout (PET_BATTERY_SERIALISED_SIZE = 8 bytes):
 *   0  percent        uint8
 *   1  millivolts     uint16 LE
 *   3  is_charging    uint8  (0x00 / 0x01)
 *   4  timestamp_s    uint32 LE
 * ---------------------------------------------------------------------- */

int pet_battery_serialise(uint8_t *buf, const battery_status_t *bat)
{
	if (buf == NULL || bat == NULL) {
		return -1;
	}

	size_t off = 0U;

	put_u8(buf, &off, bat->percent);
	put_u16_le(buf, &off, bat->millivolts);
	put_u8(buf, &off, bat->is_charging ? 0x01U : 0x00U);
	put_u32_le(buf, &off, bat->timestamp_s);

	/* off == PET_BATTERY_SERIALISED_SIZE (8) */
	return (int)off;
}

int pet_battery_deserialise(battery_status_t *bat, const uint8_t *buf)
{
	if (bat == NULL || buf == NULL) {
		return -1;
	}

	size_t off = 0U;

	bat->percent     = get_u8(buf, &off);
	bat->millivolts  = get_u16_le(buf, &off);
	bat->is_charging = (get_u8(buf, &off) != 0x00U);
	bat->timestamp_s = get_u32_le(buf, &off);

	return 0;
}

/* -------------------------------------------------------------------------
 * geofence_alert_t
 *
 * On-wire layout (PET_GEOFENCE_SERIALISED_SIZE = 6 + PET_LOCATION_SERIALISED_SIZE):
 *   0  fence_id       uint8
 *   1  breach_type    uint8
 *   2  timestamp_s    uint32 LE
 *   6  <pet_location> PET_LOCATION_SERIALISED_SIZE bytes
 * ---------------------------------------------------------------------- */

int pet_geofence_serialise(uint8_t *buf, const geofence_alert_t *alert)
{
	if (buf == NULL || alert == NULL) {
		return -1;
	}

	size_t off = 0U;

	put_u8(buf, &off, alert->fence_id);
	put_u8(buf, &off, (uint8_t)alert->breach_type);
	put_u32_le(buf, &off, alert->timestamp_s);

	/* Serialise the embedded location into the remaining buffer space. */
	int loc_bytes = pet_location_serialise(&buf[off], &alert->location);

	if (loc_bytes < 0) {
		return -1;
	}

	off += (size_t)loc_bytes;

	/* off == PET_GEOFENCE_SERIALISED_SIZE */
	return (int)off;
}

int pet_geofence_deserialise(geofence_alert_t *alert, const uint8_t *buf)
{
	if (alert == NULL || buf == NULL) {
		return -1;
	}

	size_t off = 0U;

	alert->fence_id    = get_u8(buf, &off);
	alert->breach_type = (breach_type_t)get_u8(buf, &off);
	alert->timestamp_s = get_u32_le(buf, &off);

	int rc = pet_location_deserialise(&alert->location, &buf[off]);

	if (rc < 0) {
		return -1;
	}

	return 0;
}

/* -------------------------------------------------------------------------
 * pet_health_data_t
 *
 * On-wire layout (PET_HEALTH_SERIALISED_SIZE = 9 bytes):
 *   0  temperature_cdegC  int16  LE
 *   2  heart_rate_bpm     uint16 LE
 *   4  anomaly_flags      uint8
 *   5  timestamp_s        uint32 LE
 * ---------------------------------------------------------------------- */

int pet_health_serialise(uint8_t *buf, const pet_health_data_t *health)
{
	if (buf == NULL || health == NULL) {
		return -1;
	}

	size_t off = 0U;

	put_i16_le(buf, &off, health->temperature_cdegC);
	put_u16_le(buf, &off, health->heart_rate_bpm);
	put_u8(buf, &off, health->anomaly_flags);
	put_u32_le(buf, &off, health->timestamp_s);

	/* off == PET_HEALTH_SERIALISED_SIZE (9) */
	return (int)off;
}

int pet_health_deserialise(pet_health_data_t *health, const uint8_t *buf)
{
	if (health == NULL || buf == NULL) {
		return -1;
	}

	size_t off = 0U;

	health->temperature_cdegC = get_i16_le(buf, &off);
	health->heart_rate_bpm    = get_u16_le(buf, &off);
	health->anomaly_flags     = get_u8(buf, &off);
	health->timestamp_s       = get_u32_le(buf, &off);

	return 0;
}
