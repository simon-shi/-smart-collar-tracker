/*
 * Copyright (c) 2024 Smart Pet Collar Tracker
 * SPDX-License-Identifier: Apache-2.0
 *
 * nRF9160 application main entry point.
 * Initialises all subsystems in dependency order, then runs the main
 * supervisory loop driven by a k_timer.
 */

#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>
#include <zephyr/sys/reboot.h>
#include <zephyr/task_wdt/task_wdt.h>

#include "led/led_controller.h"
#include "uart_bridge/uart_bridge.h"
#include "sensors/lsm6dso_driver.h"
#include "sensors/activity_classifier.h"
#include "power/power_manager.h"
#include "lte/lte_manager.h"
#include "gps/gps_controller.h"
#include "gps/offline_track.h"
#include "cloud/cloud_connector.h"
#include "cloud/codec.h"
#include "geofence/geofence_engine.h"

LOG_MODULE_REGISTER(main, LOG_LEVEL_INF);

/* ── Supervisory loop period ─────────────────────────────────────────────── */
#define MAIN_LOOP_PERIOD_MS  1000

/* ── Task watchdog channel ───────────────────────────────────────────────── */
static int wdt_channel_id;

/* ── GPS fix callback – publishes telemetry via cloud connector ───────────── */
static void on_gps_fix(const struct pet_location *loc)
{
	char buf[MQTT_PAYLOAD_MAX_SIZE];
	int  len;
	int  rsrp, rsrq;
	struct activity_summary act_sum;
	battery_status_t bat;

	activity_get_summary(&act_sum);
	bat.percent    = power_get_battery_percent();
	bat.millivolts = power_get_battery_mv();
	bat.is_charging = false;

	lte_get_signal_quality(&rsrp, &rsrq);

	len = codec_encode_telemetry(buf, sizeof(buf), loc,
				     &act_sum, &bat, rsrp, rsrq);
	if (len < 0) {
		LOG_ERR("Telemetry encode failed: %d", len);
		return;
	}

	geofence_check_position((double)loc->latitude_udeg  / 1e6,
				(double)loc->longitude_udeg / 1e6);

	if (lte_is_connected()) {
		cloud_publish_telemetry(buf, (size_t)len);
	} else {
		/* Store for offline sync */
		flash_track_record_t rec = {
			.latitude_udeg  = loc->latitude_udeg,
			.longitude_udeg = loc->longitude_udeg,
			.altitude_m     = (int16_t)(loc->altitude_mm / 1000),
			.timestamp_s    = loc->timestamp_s,
			.speed_kmh      = (uint8_t)(loc->speed_mmps * 36 / 10000),
			.heading_deg_div2 = (uint8_t)(loc->heading_cdeg / 200),
			.flags          = TRACK_FLAG_GPS_VALID,
			.activity_type  = (uint8_t)act_sum.dominant_activity,
		};
		offline_track_store(&rec);
	}
}

/* ── Geofence alert callback ─────────────────────────────────────────────── */
static void on_geofence_alert(const geofence_alert_t *alert)
{
	char buf[512];
	int  len;

	LOG_WRN("Geofence %s: fence_id=%u",
		alert->breach_type == BREACH_EXIT ? "EXIT" : "ENTER",
		alert->fence_id);

	len = codec_encode_alert(buf, sizeof(buf), ALERT_TYPE_GEOFENCE, alert);
	if (len < 0) {
		LOG_ERR("Alert encode failed: %d", len);
		return;
	}

	if (lte_is_connected()) {
		cloud_publish_alert(buf, (size_t)len);
	}

	led_set_pattern(LED_BLINK);
}

/* ── Cloud command callback ──────────────────────────────────────────────── */
static void on_cloud_command(const char *topic, const char *payload, size_t len)
{
	struct collar_command cmd;
	int ret;

	ret = codec_decode_command(payload, len, &cmd);
	if (ret < 0) {
		LOG_ERR("Command decode failed: %d", ret);
		return;
	}

	LOG_INF("Cloud command received: type=%d", cmd.type);

	switch (cmd.type) {
	case CMD_TYPE_SET_POWER_MODE:
		power_set_mode((power_mode_t)cmd.param.power_mode);
		break;
	case CMD_TYPE_FIND_PET:
		led_night_search_mode(true);
		uart_bridge_send(CMD_FIND_PET, NULL, 0);
		break;
	case CMD_TYPE_LED_PATTERN:
		led_set_pattern((led_pattern_t)cmd.param.led_pattern);
		break;
	case CMD_TYPE_ADD_GEOFENCE:
		geofence_add_circle(cmd.param.geofence.id,
				    cmd.param.geofence.lat,
				    cmd.param.geofence.lon,
				    cmd.param.geofence.radius_m);
		break;
	case CMD_TYPE_REMOVE_GEOFENCE:
		geofence_remove(cmd.param.geofence.id);
		break;
	case CMD_TYPE_SYNC_OFFLINE:
		/* Trigger offline track upload */
		while (offline_track_has_data()) {
			flash_track_record_t rec;
			if (offline_track_read_next(&rec) == 0) {
				/* Pack as mini JSON and publish */
				char tbuf[256];
				int tlen = snprintf(tbuf, sizeof(tbuf),
					"{\"ts\":%u,\"lat\":%d,\"lon\":%d,"
					"\"spd\":%u,\"act\":%u,\"offline\":true}",
					rec.timestamp_s,
					rec.latitude_udeg,
					rec.longitude_udeg,
					(unsigned)rec.speed_kmh,
					(unsigned)rec.activity_type);
				if (tlen > 0) {
					cloud_publish_telemetry(tbuf, (size_t)tlen);
				}
			}
		}
		break;
	default:
		LOG_WRN("Unknown command type: %d", cmd.type);
		break;
	}
}

/* ── LTE event callback ──────────────────────────────────────────────────── */
static void on_lte_event(enum lte_event event)
{
	switch (event) {
	case LTE_EVENT_CONNECTED:
		LOG_INF("LTE connected – connecting to cloud");
		cloud_connector_connect();
		cloud_subscribe_commands();
		break;
	case LTE_EVENT_DISCONNECTED:
		LOG_WRN("LTE disconnected");
		cloud_connector_disconnect();
		break;
	case LTE_EVENT_PSM_UPDATE:
		LOG_DBG("LTE PSM parameters updated");
		break;
	case LTE_EVENT_EDRX_UPDATE:
		LOG_DBG("LTE eDRX parameters updated");
		break;
	default:
		break;
	}
}

/* ── Battery low callback ────────────────────────────────────────────────── */
static void on_battery_low(uint8_t percent)
{
	LOG_WRN("Battery low: %u%%", percent);
	if (percent <= BATTERY_CRITICAL_THRESHOLD_PCT) {
		LOG_ERR("Critical battery – entering deep sleep");
		power_set_mode(PWR_DEEP_SLEEP);
	} else if (percent <= BATTERY_LOW_THRESHOLD_PCT) {
		power_set_mode(PWR_LOW_POWER);
		led_set_pattern(LED_BLINK);
	}
}

/* ── UART bridge callbacks for incoming nRF52840 data ───────────────────── */
static void on_uart_activity_data(const uint8_t *payload, uint16_t len)
{
	pet_activity_data_t act;

	if (pet_activity_deserialise(&act, payload) != 0) {
		LOG_ERR("Activity deserialise failed");
		return;
	}
	LOG_DBG("Activity: type=%d steps=%u", act.activity_type, act.steps);
}

static void on_uart_health_data(const uint8_t *payload, uint16_t len)
{
	pet_health_data_t health;

	if (pet_health_deserialise(&health, payload) != 0) {
		LOG_ERR("Health deserialise failed");
		return;
	}
	LOG_DBG("Health: temp=%d bpm=%u flags=0x%02X",
		health.temperature_cdegC, health.heart_rate_bpm,
		health.anomaly_flags);
}

/* ── Main entry point ────────────────────────────────────────────────────── */
int main(void)
{
	int ret;

	LOG_INF("Smart Pet Collar nRF9160 v%u.%u.%u starting",
		FW_VERSION_MAJOR, FW_VERSION_MINOR, FW_VERSION_PATCH);

	/* 1. LED controller – gives early visual feedback */
	ret = led_controller_init();
	if (ret < 0) {
		LOG_ERR("LED init failed: %d", ret);
	} else {
		led_set_pattern(LED_BLINK);
	}

	/* 2. UART bridge – needed before any nRF52840 comms */
	ret = uart_bridge_init();
	if (ret < 0) {
		LOG_ERR("UART bridge init failed: %d", ret);
	}
	uart_bridge_register_callback(CMD_ACTIVITY_DATA, on_uart_activity_data);
	uart_bridge_register_callback(CMD_HEALTH_DATA,   on_uart_health_data);

	/* 3. LSM6DSO IMU */
	ret = lsm6dso_init();
	if (ret < 0) {
		LOG_ERR("LSM6DSO init failed: %d", ret);
	} else {
		lsm6dso_configure_accel(LSM6DSO_ODR_26HZ, LSM6DSO_FS_4G);
		lsm6dso_configure_wakeup(LSM6DSO_ACTIVITY_THRESHOLD_MG);
	}

	/* 4. Activity classifier */
	ret = activity_classifier_init();
	if (ret < 0) {
		LOG_ERR("Activity classifier init failed: %d", ret);
	}

	/* 5. Power manager */
	ret = power_manager_init();
	if (ret < 0) {
		LOG_ERR("Power manager init failed: %d", ret);
	}
	power_register_battery_callback(on_battery_low);

	/* 6. Offline track storage */
	ret = offline_track_init();
	if (ret < 0) {
		LOG_ERR("Offline track init failed: %d", ret);
	}

	/* 7. Geofence engine */
	ret = geofence_engine_init();
	if (ret < 0) {
		LOG_ERR("Geofence engine init failed: %d", ret);
	}
	geofence_register_alert_callback(on_geofence_alert);

	/* 8. LTE manager */
	ret = lte_manager_init();
	if (ret < 0) {
		LOG_ERR("LTE manager init failed: %d", ret);
	}
	lte_register_event_callback(on_lte_event);

	/* 9. GPS controller */
	ret = gps_controller_init();
	if (ret < 0) {
		LOG_ERR("GPS controller init failed: %d", ret);
	}
	gps_register_fix_callback(on_gps_fix);

	/* 10. Cloud connector */
	ret = cloud_connector_init();
	if (ret < 0) {
		LOG_ERR("Cloud connector init failed: %d", ret);
	}
	cloud_register_command_callback(on_cloud_command);

	/* 11. Start LTE (async – event callback drives cloud connection) */
	ret = lte_manager_connect();
	if (ret < 0) {
		LOG_ERR("LTE connect failed: %d – operating offline", ret);
	}

	/* 12. Start GPS */
	ret = gps_controller_start();
	if (ret < 0) {
		LOG_ERR("GPS start failed: %d", ret);
	}

	/* 13. Task watchdog */
	wdt_channel_id = task_wdt_add(WATCHDOG_TIMEOUT_MS, NULL, NULL);
	if (wdt_channel_id < 0) {
		LOG_ERR("Task WDT add failed: %d", wdt_channel_id);
	}

	led_set_pattern(LED_SOLID);
	LOG_INF("Initialisation complete – entering main loop");

	/* Main supervisory loop */
	while (true) {
		task_wdt_feed(wdt_channel_id);
		k_sleep(K_MSEC(MAIN_LOOP_PERIOD_MS));
	}

	/* Unreachable */
	return 0;
}
