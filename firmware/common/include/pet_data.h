/*
 * Copyright (c) 2024 Smart Pet Collar Tracker
 * SPDX-License-Identifier: Apache-2.0
 *
 * Shared data structures exchanged between the nRF9160 modem MCU and the
 * nRF52840 sensor/BLE MCU, and published upstream via MQTT.
 *
 * All multi-byte integer fields are stored in little-endian byte order
 * in serialised form.  Floating-point geographic coordinates are scaled
 * to signed 32-bit integers (microdegrees, factor 1 × 10⁻⁶) so that no
 * floating-point library is required on constrained targets.
 *
 * Serialisation buffer size macros are provided alongside each structure
 * for use in protocol_encode / protocol_decode callers.
 */

#ifndef FIRMWARE_COMMON_PET_DATA_H_
#define FIRMWARE_COMMON_PET_DATA_H_

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/* -------------------------------------------------------------------------
 * Enumerations
 * ---------------------------------------------------------------------- */

/**
 * @brief Classified pet activity type.
 *
 * Determined by the accelerometer / activity-recognition algorithm running
 * on the nRF52840.
 */
typedef enum pet_activity_type {
	ACT_REST  = 0, /**< Resting / stationary.   */
	ACT_WALK  = 1, /**< Walking.                */
	ACT_RUN   = 2, /**< Running.                */
	ACT_PLAY  = 3, /**< Active play.            */
	ACT_SWIM  = 4, /**< Swimming.               */
	ACT_SLEEP = 5, /**< Sleeping.               */
} pet_activity_type_t;

/**
 * @brief Device power operating mode.
 *
 * Controls GPS fix rate, LTE report interval, BLE advertising interval, and
 * sensor ODR.  Matches the CMD_POWER_MODE payload value.
 */
typedef enum power_mode {
	PWR_DEEP_SLEEP = 0, /**< Minimum power; GPS off; LTE PSM; BLE off.      */
	PWR_LOW_POWER  = 1, /**< Infrequent GPS + LTE; BLE beaconing only.      */
	PWR_ACTIVE     = 2, /**< Regular GPS + LTE reporting; BLE connectable.  */
	PWR_TRACKING   = 3, /**< High-rate GPS; continuous LTE; BLE connectable.*/
} power_mode_t;

/**
 * @brief Geofence breach direction.
 */
typedef enum breach_type {
	BREACH_ENTER = 0, /**< Pet entered a monitored zone.  */
	BREACH_EXIT  = 1, /**< Pet exited a monitored zone.   */
} breach_type_t;

/* -------------------------------------------------------------------------
 * GPS / Location
 * ---------------------------------------------------------------------- */

/**
 * @brief Single GPS fix result.
 *
 * Coordinates use microdegrees (1e-6 °) as signed 32-bit integers to avoid
 * floating-point arithmetic on constrained targets:
 *   latitude_udeg  ∈ [−90 000 000, +90 000 000]
 *   longitude_udeg ∈ [−180 000 000, +180 000 000]
 *
 * altitude_mm   : metres above WGS-84 ellipsoid × 1000 (millimetres).
 * speed_mmps    : ground speed in millimetres per second.
 * heading_cdeg  : true heading in centidegrees (0–35 999).
 * accuracy_mm   : horizontal accuracy estimate in millimetres (CEP 68 %).
 * timestamp_s   : Unix epoch seconds (UTC).
 * fix_quality   : 0 = no fix, 1 = GPS, 2 = DGPS, 4 = RTK fixed.
 * satellites    : number of satellites used in fix.
 */
typedef struct pet_location {
	int32_t  latitude_udeg;   /**< Latitude  ×10⁻⁶ degrees.          */
	int32_t  longitude_udeg;  /**< Longitude ×10⁻⁶ degrees.          */
	int32_t  altitude_mm;     /**< Altitude in millimetres (WGS-84).  */
	uint32_t speed_mmps;      /**< Ground speed mm/s.                 */
	uint16_t heading_cdeg;    /**< True heading centidegrees 0–35999. */
	uint32_t accuracy_mm;     /**< Horizontal accuracy estimate mm.   */
	uint32_t timestamp_s;     /**< Unix epoch seconds UTC.            */
	uint8_t  fix_quality;     /**< NMEA fix quality indicator.        */
	uint8_t  satellites;      /**< Satellites used.                   */
} pet_location_t;

/** Serialised size of pet_location_t (bytes). */
#define PET_LOCATION_SERIALISED_SIZE  26U

/* -------------------------------------------------------------------------
 * Activity data
 * ---------------------------------------------------------------------- */

/**
 * @brief Aggregated pet activity record for a reporting interval.
 *
 * steps         : total step count since last reset.
 * calories_mcal : estimated energy expenditure in milli-calories.
 * duration_s    : duration of the current activity window in seconds.
 * activity_type : dominant activity classification for this window.
 * timestamp_s   : Unix epoch seconds when the record was finalised.
 */
typedef struct pet_activity_data {
	uint32_t            steps;
	uint32_t            calories_mcal;
	uint32_t            duration_s;
	uint32_t            timestamp_s;
	pet_activity_type_t activity_type;
} pet_activity_data_t;

/** Serialised size of pet_activity_data_t (bytes). */
#define PET_ACTIVITY_SERIALISED_SIZE  17U

/* -------------------------------------------------------------------------
 * Health data
 * ---------------------------------------------------------------------- */

/**
 * @brief Pet health sensor snapshot.
 *
 * temperature_cdegC : body temperature in centi-degrees Celsius
 *                     (e.g., 3850 = 38.50 °C).
 * heart_rate_bpm    : heart rate in beats per minute (0 = not measured).
 * anomaly_flags     : bitfield of detected anomalies (see HEALTH_ANOMALY_*).
 * timestamp_s       : Unix epoch seconds UTC.
 */
typedef struct pet_health_data {
	int16_t  temperature_cdegC;
	uint16_t heart_rate_bpm;
	uint8_t  anomaly_flags;
	uint32_t timestamp_s;
} pet_health_data_t;

/*
 * BIT(n) is provided by Zephyr's <sys/util.h>.  Define a fallback for
 * host-side unit tests and non-Zephyr build environments.
 */
#ifndef BIT
#define BIT(n) (1UL << (n))
#endif

/** Anomaly flag bits for pet_health_data_t::anomaly_flags. */
#define HEALTH_ANOMALY_TEMP_HIGH   ((uint8_t)BIT(0)) /**< Temperature above threshold.  */
#define HEALTH_ANOMALY_TEMP_LOW    ((uint8_t)BIT(1)) /**< Temperature below threshold.  */
#define HEALTH_ANOMALY_HR_HIGH     ((uint8_t)BIT(2)) /**< Heart rate above threshold.   */
#define HEALTH_ANOMALY_HR_LOW      ((uint8_t)BIT(3)) /**< Heart rate below threshold.   */
#define HEALTH_ANOMALY_INACTIVITY  ((uint8_t)BIT(4)) /**< Extended inactivity detected. */

/** Serialised size of pet_health_data_t (bytes). */
#define PET_HEALTH_SERIALISED_SIZE  9U

/* -------------------------------------------------------------------------
 * Battery status
 * ---------------------------------------------------------------------- */

/**
 * @brief Battery and charging state.
 *
 * percent     : state of charge 0–100 %.
 * millivolts  : terminal voltage in mV.
 * is_charging : true when a charge source is connected.
 * timestamp_s : Unix epoch seconds UTC.
 */
typedef struct battery_status {
	uint8_t  percent;
	uint16_t millivolts;
	bool     is_charging;
	uint32_t timestamp_s;
} battery_status_t;

/** Serialised size of battery_status_t (bytes). */
#define PET_BATTERY_SERIALISED_SIZE  8U

/* -------------------------------------------------------------------------
 * Geofence alert
 * ---------------------------------------------------------------------- */

/**
 * @brief Geofence breach event.
 *
 * fence_id     : user-defined geofence identifier (0-based).
 * breach_type  : BREACH_ENTER or BREACH_EXIT.
 * timestamp_s  : Unix epoch seconds UTC when breach was detected.
 * location     : GPS fix at the moment of the breach (may be the last valid
 *               fix if GPS was unavailable at breach detection time).
 */
typedef struct geofence_alert {
	uint8_t        fence_id;
	breach_type_t  breach_type;
	uint32_t       timestamp_s;
	pet_location_t location;
} geofence_alert_t;

/**
 * Serialised size: fence_id(1) + breach_type(1) + timestamp(4)
 *                + PET_LOCATION_SERIALISED_SIZE(26) = 32 bytes.
 */
#define PET_GEOFENCE_SERIALISED_SIZE  (6U + PET_LOCATION_SERIALISED_SIZE)

/* -------------------------------------------------------------------------
 * Device status
 * ---------------------------------------------------------------------- */

/**
 * @brief Full device status snapshot returned in CMD_STATUS_RESP.
 *
 * power_mode       : current operating power mode.
 * fw_version_major : firmware major version (nRF9160 application).
 * fw_version_minor : firmware minor version.
 * fw_version_patch : firmware patch level.
 * rsrp_dbm         : LTE reference signal received power (dBm, negative).
 * rsrq_db          : LTE reference signal received quality (dB, negative).
 * battery          : embedded battery status snapshot.
 * uptime_s         : device uptime in seconds since last reset.
 */
typedef struct device_status {
	power_mode_t     power_mode;
	uint8_t          fw_version_major;
	uint8_t          fw_version_minor;
	uint8_t          fw_version_patch;
	int16_t          rsrp_dbm;
	int16_t          rsrq_db;
	battery_status_t battery;
	uint32_t         uptime_s;
} device_status_t;

/**
 * Serialised size: power_mode(1) + fw(3) + rsrp(2) + rsrq(2)
 *                + PET_BATTERY_SERIALISED_SIZE(8) + uptime(4) = 20 bytes.
 */
#define PET_DEVICE_STATUS_SERIALISED_SIZE  20U

/* -------------------------------------------------------------------------
 * Flash track record (compact offline storage format)
 * ---------------------------------------------------------------------- */

/**
 * @brief Compact track record written to NOR flash during offline operation.
 *
 * Uses FLASH_TRACK_RECORD_SIZE (18) bytes on flash.  Fields use scaled
 * integers to achieve compact representation.
 *
 * latitude_udeg  : 4 bytes LE signed (microdegrees).
 * longitude_udeg : 4 bytes LE signed (microdegrees).
 * altitude_m     : 2 bytes LE signed (whole metres, range ±32 767 m).
 * timestamp_s    : 4 bytes LE unsigned Unix epoch.
 * speed_kmh      : 1 byte  unsigned (km/h, 0–255).
 * heading_deg    : 1 byte  unsigned (degrees / 2, range 0–179 → 0–358 °).
 * flags          : 1 byte  bitfield (TRACK_FLAG_*).
 * activity_type  : 1 byte  pet_activity_type_t value.
 *
 * Total: 4+4+2+4+1+1+1+1 = 18 bytes.
 */
typedef struct flash_track_record {
	int32_t  latitude_udeg;
	int32_t  longitude_udeg;
	int16_t  altitude_m;
	uint32_t timestamp_s;
	uint8_t  speed_kmh;
	uint8_t  heading_deg_div2;
	uint8_t  flags;
	uint8_t  activity_type;
} flash_track_record_t;

/** Flag bits for flash_track_record_t::flags. */
#define TRACK_FLAG_GPS_VALID   ((uint8_t)BIT(0)) /**< GPS fix was valid.                */
#define TRACK_FLAG_CHARGING    ((uint8_t)BIT(1)) /**< Battery was charging at this fix. */
#define TRACK_FLAG_GEOFENCE    ((uint8_t)BIT(2)) /**< Geofence event co-located here.   */

/* -------------------------------------------------------------------------
 * Serialisation function prototypes (implemented in pet_data.c)
 * ---------------------------------------------------------------------- */

/**
 * @brief Serialise a pet_location_t into a little-endian byte buffer.
 *
 * @param[out] buf      Output buffer (must be >= PET_LOCATION_SERIALISED_SIZE).
 * @param[in]  loc      Source structure.
 * @return Number of bytes written (PET_LOCATION_SERIALISED_SIZE), or -1 on
 *         error (NULL pointer).
 */
int pet_location_serialise(uint8_t *buf, const pet_location_t *loc);

/**
 * @brief Deserialise a little-endian byte buffer into a pet_location_t.
 *
 * @param[out] loc      Destination structure.
 * @param[in]  buf      Input buffer (must be >= PET_LOCATION_SERIALISED_SIZE).
 * @return 0 on success, -1 on NULL pointer.
 */
int pet_location_deserialise(pet_location_t *loc, const uint8_t *buf);

/**
 * @brief Serialise a pet_activity_data_t into a little-endian byte buffer.
 *
 * @param[out] buf      Output buffer (>= PET_ACTIVITY_SERIALISED_SIZE).
 * @param[in]  act      Source structure.
 * @return Number of bytes written, or -1 on error.
 */
int pet_activity_serialise(uint8_t *buf, const pet_activity_data_t *act);

/**
 * @brief Deserialise a little-endian byte buffer into a pet_activity_data_t.
 *
 * @param[out] act      Destination structure.
 * @param[in]  buf      Input buffer (>= PET_ACTIVITY_SERIALISED_SIZE).
 * @return 0 on success, -1 on error.
 */
int pet_activity_deserialise(pet_activity_data_t *act, const uint8_t *buf);

/**
 * @brief Serialise a battery_status_t into a little-endian byte buffer.
 *
 * @param[out] buf      Output buffer (>= PET_BATTERY_SERIALISED_SIZE).
 * @param[in]  bat      Source structure.
 * @return Number of bytes written, or -1 on error.
 */
int pet_battery_serialise(uint8_t *buf, const battery_status_t *bat);

/**
 * @brief Deserialise a little-endian byte buffer into a battery_status_t.
 *
 * @param[out] bat      Destination structure.
 * @param[in]  buf      Input buffer (>= PET_BATTERY_SERIALISED_SIZE).
 * @return 0 on success, -1 on error.
 */
int pet_battery_deserialise(battery_status_t *bat, const uint8_t *buf);

/**
 * @brief Serialise a geofence_alert_t into a little-endian byte buffer.
 *
 * @param[out] buf      Output buffer (>= PET_GEOFENCE_SERIALISED_SIZE).
 * @param[in]  alert    Source structure.
 * @return Number of bytes written, or -1 on error.
 */
int pet_geofence_serialise(uint8_t *buf, const geofence_alert_t *alert);

/**
 * @brief Deserialise a little-endian byte buffer into a geofence_alert_t.
 *
 * @param[out] alert    Destination structure.
 * @param[in]  buf      Input buffer (>= PET_GEOFENCE_SERIALISED_SIZE).
 * @return 0 on success, -1 on error.
 */
int pet_geofence_deserialise(geofence_alert_t *alert, const uint8_t *buf);

/**
 * @brief Serialise a pet_health_data_t into a little-endian byte buffer.
 *
 * @param[out] buf      Output buffer (>= PET_HEALTH_SERIALISED_SIZE).
 * @param[in]  health   Source structure.
 * @return Number of bytes written, or -1 on error.
 */
int pet_health_serialise(uint8_t *buf, const pet_health_data_t *health);

/**
 * @brief Deserialise a little-endian byte buffer into a pet_health_data_t.
 *
 * @param[out] health   Destination structure.
 * @param[in]  buf      Input buffer (>= PET_HEALTH_SERIALISED_SIZE).
 * @return 0 on success, -1 on error.
 */
int pet_health_deserialise(pet_health_data_t *health, const uint8_t *buf);

#ifdef __cplusplus
}
#endif

#endif /* FIRMWARE_COMMON_PET_DATA_H_ */
