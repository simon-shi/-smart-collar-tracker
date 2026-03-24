/*
 * Copyright (c) 2024 Smart Pet Collar Tracker
 * SPDX-License-Identifier: Apache-2.0
 *
 * Global compile-time configuration constants shared between the nRF9160
 * application firmware and the nRF52840 sensor/BLE firmware.
 *
 * Values are expressed as pre-processor constants rather than variables so
 * that they can be used in static-assert expressions and linker scripts.
 *
 * Tunable parameters (those expected to change between hardware revisions or
 * deployment regions) are grouped separately from structural constants.
 */

#ifndef FIRMWARE_COMMON_CONFIG_H_
#define FIRMWARE_COMMON_CONFIG_H_

#ifdef __cplusplus
extern "C" {
#endif

/* =========================================================================
 * Device identity
 * ====================================================================== */

/** BLE advertising name prefix.  Full name is "<PREFIX>-<XXXX>" where XXXX
 *  is the last four hex digits of the device's 64-bit hardware ID. */
#define DEVICE_NAME_PREFIX              "PetCollar"

/** Maximum length (bytes, including NUL) of the full device name string. */
#define DEVICE_NAME_MAX_LEN             24U

/* =========================================================================
 * Cloud connectivity
 * ====================================================================== */

/** AWS IoT Core or custom MQTT broker endpoint (TLS, port 8883).
 *  Override at build time with -DMQTT_BROKER_ENDPOINT='"your.host.com"'. */
#ifndef MQTT_BROKER_ENDPOINT
#define MQTT_BROKER_ENDPOINT            "mqtt.example.com"
#endif

/** MQTT broker TLS port. */
#define MQTT_BROKER_PORT                8883U

/** MQTT keep-alive interval in seconds. */
#define MQTT_KEEPALIVE_S                60U

/** MQTT QoS level for telemetry topics (0 = at-most-once, 1 = at-least-once). */
#define MQTT_QOS_TELEMETRY              1U

/** MQTT QoS level for command/control topics. */
#define MQTT_QOS_COMMANDS               1U

/** Maximum size of an MQTT topic string (bytes, including NUL). */
#define MQTT_TOPIC_MAX_LEN              128U

/** Maximum MQTT publish payload size (bytes). */
#define MQTT_PAYLOAD_MAX_SIZE           2048U

/* =========================================================================
 * Geofencing
 * ====================================================================== */

/** Maximum number of simultaneously active geofence zones. */
#define MAX_GEOFENCES                   10U

/** Default circular geofence radius in metres when no radius is specified. */
#define DEFAULT_GEOFENCE_RADIUS_M       200U

/** Minimum allowed geofence radius in metres. */
#define MIN_GEOFENCE_RADIUS_M           50U

/** Maximum allowed geofence radius in metres. */
#define MAX_GEOFENCE_RADIUS_M           50000U

/** Hysteresis band added to the fence radius on re-entry evaluation (metres).
 *  Prevents oscillation near the fence boundary. */
#define GEOFENCE_HYSTERESIS_M           20U

/* =========================================================================
 * GPS / GNSS fix intervals (seconds, 0 = disabled)
 * ====================================================================== */

/** Fix attempt interval in PWR_TRACKING mode (highest rate). */
#define GPS_FIX_INTERVAL_TRACKING_S     10U

/** Fix attempt interval in PWR_ACTIVE mode. */
#define GPS_FIX_INTERVAL_ACTIVE_S       60U

/** Fix attempt interval in PWR_LOW_POWER mode. */
#define GPS_FIX_INTERVAL_LOW_POWER_S    1800U

/** GPS is disabled in PWR_DEEP_SLEEP mode (value 0 = off). */
#define GPS_FIX_INTERVAL_DEEP_SLEEP_S   0U

/** Maximum time allowed for a single GPS fix attempt in seconds. */
#define GPS_FIX_TIMEOUT_S               120U

/** Minimum acceptable horizontal accuracy (mm) to accept a fix. */
#define GPS_MIN_ACCURACY_MM             50000U   /* 50 m */

/* =========================================================================
 * LTE / cloud report intervals (seconds)
 * ====================================================================== */

/** LTE upload interval in PWR_TRACKING mode. */
#define LTE_REPORT_INTERVAL_TRACKING_S  15U

/** LTE upload interval in PWR_ACTIVE mode. */
#define LTE_REPORT_INTERVAL_ACTIVE_S    120U

/** LTE upload interval in PWR_LOW_POWER mode. */
#define LTE_REPORT_INTERVAL_LOW_POWER_S 3600U

/** LTE is in PSM in PWR_DEEP_SLEEP; wakes once per TAU period (seconds). */
#define LTE_REPORT_INTERVAL_DEEP_SLEEP_S 43200U  /* 12 hours */

/** LTE connection attempt timeout in seconds before declaring no coverage. */
#define LTE_CONNECT_TIMEOUT_S           300U

/** Number of consecutive LTE failures before switching to offline mode. */
#define LTE_MAX_CONSECUTIVE_FAILURES    5U

/* =========================================================================
 * Battery management
 * ====================================================================== */

/** Battery percentage below which "low battery" warning is issued. */
#define BATTERY_LOW_THRESHOLD_PCT       10U

/** Battery percentage below which the device enters forced deep-sleep. */
#define BATTERY_CRITICAL_THRESHOLD_PCT  5U

/** Minimum battery percentage required to attempt a firmware update. */
#define BATTERY_DFU_MIN_PCT             30U

/** ADC oversampling count for battery voltage measurement. */
#define BATTERY_ADC_OVERSAMPLE          8U

/** Battery voltage at 100 % SoC in millivolts (Li-Ion 4.2 V). */
#define BATTERY_FULL_MV                 4200U

/** Battery voltage at 0 % SoC in millivolts (Li-Ion cutoff 3.0 V). */
#define BATTERY_EMPTY_MV                3000U

/* =========================================================================
 * Flash (NOR, SPI)
 * ====================================================================== */

/** Flash sector (erase block) size in bytes. */
#define FLASH_SECTOR_SIZE               4096U

/** Flash page (write buffer) size in bytes. */
#define FLASH_PAGE_SIZE                 256U

/** Total flash capacity dedicated to offline track storage in bytes (512 kB). */
#define FLASH_TRACK_STORAGE_SIZE        (512U * 1024U)

/**
 * Compact track record size in bytes written to NOR flash.
 *
 * Layout (all LE):
 *   Offset  0 : int32_t  latitude_udeg      (4 bytes)
 *   Offset  4 : int32_t  longitude_udeg     (4 bytes)
 *   Offset  8 : int16_t  altitude_m         (2 bytes)
 *   Offset 10 : uint32_t timestamp_s        (4 bytes)
 *   Offset 14 : uint8_t  speed_kmh          (1 byte)
 *   Offset 15 : uint8_t  heading_deg_div2   (1 byte)
 *   Offset 16 : uint8_t  flags              (1 byte)
 *   Offset 17 : uint8_t  activity_type      (1 byte)
 *   ---
 *   Total    : 18 bytes
 */
#define FLASH_TRACK_RECORD_SIZE         18U

/* Field offsets within a serialised flash track record. */
#define FLASH_TR_OFFSET_LAT             0U
#define FLASH_TR_OFFSET_LON             4U
#define FLASH_TR_OFFSET_ALT             8U
#define FLASH_TR_OFFSET_TIMESTAMP       10U
#define FLASH_TR_OFFSET_SPEED           14U
#define FLASH_TR_OFFSET_HEADING         15U
#define FLASH_TR_OFFSET_FLAGS           16U
#define FLASH_TR_OFFSET_ACTIVITY        17U

/** Maximum number of track records in offline storage. */
#define FLASH_MAX_TRACK_RECORDS  \
	(FLASH_TRACK_STORAGE_SIZE / FLASH_TRACK_RECORD_SIZE)

/** Magic word written at the start of a valid flash log header (ASCII "PCT1"). */
#define FLASH_LOG_MAGIC                 0x50435431UL

/* =========================================================================
 * Inter-chip UART (nRF52840 ↔ nRF9160)
 * ====================================================================== */

/** UART baud rate in bits per second. */
#define UART_BAUD_RATE                  1000000UL

/** UART RX ring-buffer size in bytes (must be power of two). */
#define UART_RX_BUF_SIZE                1024U

/** UART TX buffer size in bytes. */
#define UART_TX_BUF_SIZE                1024U

/** Inter-packet receive timeout in milliseconds (triggers frame assembly). */
#define UART_RX_TIMEOUT_MS              10U

/** Number of retransmit attempts before declaring a packet lost. */
#define UART_MAX_RETRIES                3U

/** Retransmit back-off interval in milliseconds. */
#define UART_RETRY_INTERVAL_MS          50U

/* =========================================================================
 * BLE (nRF52840)
 * ====================================================================== */

/** BLE advertising interval in 0.625 ms units when connectable (100 ms). */
#define BLE_ADV_INTERVAL_CONNECTABLE    160U

/** BLE advertising interval in 0.625 ms units in low-power beacon mode
 *  (1000 ms). */
#define BLE_ADV_INTERVAL_LOW_POWER      1600U

/** BLE advertising interval in 0.625 ms units in tracking mode (50 ms). */
#define BLE_ADV_INTERVAL_TRACKING       80U

/** BLE advertising timeout in seconds (0 = advertise indefinitely). */
#define BLE_ADV_TIMEOUT_S               0U

/** BLE connection supervision timeout in 10 ms units (4 s). */
#define BLE_CONN_SUPERVISION_TIMEOUT    400U

/** BLE minimum connection interval in 1.25 ms units (20 ms). */
#define BLE_CONN_MIN_INTERVAL           16U

/** BLE maximum connection interval in 1.25 ms units (75 ms). */
#define BLE_CONN_MAX_INTERVAL           60U

/** BLE peripheral latency (number of connection events slave may skip). */
#define BLE_CONN_SLAVE_LATENCY          0U

/** Maximum simultaneous BLE connections. */
#define BLE_MAX_CONNECTIONS             1U

/* =========================================================================
 * LSM6DSO IMU (nRF52840, via SPI/I2C)
 * ====================================================================== */

/**
 * LSM6DSO accelerometer output data rate register values.
 * Register: CTRL1_XL [7:4] ODR_XL[3:0].
 */
#define LSM6DSO_ODR_OFF                 0x00U  /**< Power-down.             */
#define LSM6DSO_ODR_12_5HZ              0x01U  /**< 12.5 Hz low-power.      */
#define LSM6DSO_ODR_26HZ                0x02U  /**< 26 Hz.                  */
#define LSM6DSO_ODR_52HZ                0x03U  /**< 52 Hz.                  */
#define LSM6DSO_ODR_104HZ               0x04U  /**< 104 Hz (default active).*/
#define LSM6DSO_ODR_208HZ               0x05U  /**< 208 Hz.                 */
#define LSM6DSO_ODR_416HZ               0x06U  /**< 416 Hz.                 */

/** ODR used in PWR_DEEP_SLEEP (step counter keeps running at 26 Hz). */
#define LSM6DSO_ODR_DEEP_SLEEP          LSM6DSO_ODR_OFF

/** ODR used in PWR_LOW_POWER mode. */
#define LSM6DSO_ODR_LOW_POWER           LSM6DSO_ODR_12_5HZ

/** ODR used in PWR_ACTIVE mode. */
#define LSM6DSO_ODR_ACTIVE              LSM6DSO_ODR_26HZ

/** ODR used in PWR_TRACKING mode. */
#define LSM6DSO_ODR_TRACKING            LSM6DSO_ODR_104HZ

/**
 * LSM6DSO accelerometer full-scale selection (CTRL1_XL [3:2] FS_XL[1:0]).
 */
#define LSM6DSO_FS_2G                   0x00U
#define LSM6DSO_FS_16G                  0x01U
#define LSM6DSO_FS_4G                   0x02U
#define LSM6DSO_FS_8G                   0x03U

/** Full-scale used for activity classification. */
#define LSM6DSO_FS_ACTIVITY             LSM6DSO_FS_4G

/** Step-counter debounce threshold (register PEDO_DEB_STEPS_CONF). */
#define LSM6DSO_STEP_DEBOUNCE           0x03U

/** Activity/inactivity threshold in mg (1 LSB = FS/2^16). */
#define LSM6DSO_ACTIVITY_THRESHOLD_MG   100U

/** Inactivity duration before triggering sleep transition (seconds). */
#define LSM6DSO_INACTIVITY_DURATION_S   5U

/* =========================================================================
 * DFU (Device Firmware Update)
 * ====================================================================== */

/** DFU block size in bytes carried in each CMD_DFU_DATA packet. */
#define DFU_BLOCK_SIZE                  256U

/** Maximum firmware image size in bytes (1 MiB). */
#define DFU_MAX_IMAGE_SIZE              (1024U * 1024U)

/** DFU receive window size (number of outstanding unacknowledged blocks). */
#define DFU_WINDOW_SIZE                 4U

/** DFU inter-block timeout in milliseconds. */
#define DFU_BLOCK_TIMEOUT_MS            5000U

/* =========================================================================
 * Watchdog
 * ====================================================================== */

/** Watchdog timeout in milliseconds.  Must be fed within this interval. */
#define WATCHDOG_TIMEOUT_MS             30000U

/* =========================================================================
 * Miscellaneous
 * ====================================================================== */

/** Firmware version components (override at build time as needed). */
#ifndef FW_VERSION_MAJOR
#define FW_VERSION_MAJOR                1U
#endif
#ifndef FW_VERSION_MINOR
#define FW_VERSION_MINOR                0U
#endif
#ifndef FW_VERSION_PATCH
#define FW_VERSION_PATCH                0U
#endif

/** Packed 24-bit firmware version: MAJOR<<16 | MINOR<<8 | PATCH. */
#define FW_VERSION_PACKED \
	(((uint32_t)FW_VERSION_MAJOR << 16) | \
	 ((uint32_t)FW_VERSION_MINOR <<  8) | \
	  (uint32_t)FW_VERSION_PATCH)

/** ISO 8601 build date string (injected by the build system). */
#ifndef FW_BUILD_DATE
#define FW_BUILD_DATE                   "1970-01-01"
#endif

/** Stack size for the protocol receive thread (bytes). */
#define PROTO_RX_THREAD_STACK_SIZE      1024U

/** Priority of the protocol receive thread (Zephyr cooperative). */
#define PROTO_RX_THREAD_PRIORITY        (-2)

/** Stack size for the MQTT publish thread (bytes). */
#define MQTT_THREAD_STACK_SIZE          4096U

/** Stack size for the GPS processing thread (bytes). */
#define GPS_THREAD_STACK_SIZE           2048U

#ifdef __cplusplus
}
#endif

#endif /* FIRMWARE_COMMON_CONFIG_H_ */
