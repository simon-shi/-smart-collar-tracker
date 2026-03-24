/*
 * Copyright (c) 2024 Smart Pet Collar Tracker
 * SPDX-License-Identifier: Apache-2.0
 *
 * BLE Manager – implementation.
 */

#include "ble_manager.h"
#include "services/pet_tracker_service.h"
#include "services/battery_service.h"
#include "services/device_info_service.h"

#include <zephyr/kernel.h>
#include <zephyr/bluetooth/bluetooth.h>
#include <zephyr/bluetooth/hci.h>
#include <zephyr/bluetooth/conn.h>
#include <zephyr/bluetooth/uuid.h>
#include <zephyr/bluetooth/gatt.h>
#include <zephyr/settings/settings.h>
#include <zephyr/logging/log.h>

#include "../../common/include/config.h"

LOG_MODULE_REGISTER(ble_manager, LOG_LEVEL_INF);

/* -----------------------------------------------------------------------
 * Module state
 * -------------------------------------------------------------------- */
static struct bt_conn *active_conns[CONFIG_BT_MAX_CONN];
static int            conn_count;
static K_MUTEX_DEFINE(conn_mutex);

static void (*user_conn_cb)(bool connected);

/* Advertising data */
static uint8_t ad_flags = BT_LE_AD_GENERAL | BT_LE_AD_NO_BREDR;

static const struct bt_data ad[] = {
	BT_DATA_BYTES(BT_DATA_FLAGS, BT_LE_AD_GENERAL | BT_LE_AD_NO_BREDR),
	BT_DATA(BT_DATA_COMPLETE_LOCAL_NAME,
		CONFIG_BT_DEVICE_NAME,
		sizeof(CONFIG_BT_DEVICE_NAME) - 1),
};

static const struct bt_le_adv_param adv_param_connectable =
	BT_LE_ADV_PARAM_INIT(BT_LE_ADV_OPT_CONNECTABLE |
			     BT_LE_ADV_OPT_USE_IDENTITY,
			     BLE_ADV_INTERVAL_CONNECTABLE,
			     BLE_ADV_INTERVAL_CONNECTABLE + 16,
			     NULL);

static const struct bt_le_adv_param adv_param_beacon =
	BT_LE_ADV_PARAM_INIT(BT_LE_ADV_OPT_USE_IDENTITY,
			     BLE_ADV_INTERVAL_LOW_POWER,
			     BLE_ADV_INTERVAL_LOW_POWER + 160,
			     NULL);

/* -----------------------------------------------------------------------
 * Connection callbacks
 * -------------------------------------------------------------------- */
static void on_connected(struct bt_conn *conn, uint8_t err)
{
	if (err) {
		LOG_ERR("BLE connection failed: %u", err);
		return;
	}

	k_mutex_lock(&conn_mutex, K_FOREVER);
	for (int i = 0; i < CONFIG_BT_MAX_CONN; i++) {
		if (!active_conns[i]) {
			active_conns[i] = bt_conn_ref(conn);
			conn_count++;
			break;
		}
	}
	k_mutex_unlock(&conn_mutex);

	LOG_INF("BLE connected (total: %d)", conn_count);

	if (user_conn_cb) {
		user_conn_cb(true);
	}
}

static void on_disconnected(struct bt_conn *conn, uint8_t reason)
{
	k_mutex_lock(&conn_mutex, K_FOREVER);
	for (int i = 0; i < CONFIG_BT_MAX_CONN; i++) {
		if (active_conns[i] == conn) {
			bt_conn_unref(active_conns[i]);
			active_conns[i] = NULL;
			conn_count--;
			break;
		}
	}
	k_mutex_unlock(&conn_mutex);

	LOG_INF("BLE disconnected (reason 0x%02x, remaining: %d)",
		reason, conn_count);

	if (user_conn_cb) {
		user_conn_cb(false);
	}

	/* Restart connectable advertising when no peers remain */
	if (conn_count == 0) {
		ble_start_advertising(true);
	}
}

static void on_security_changed(struct bt_conn *conn,
				bt_security_t level, enum bt_security_err err)
{
	if (err) {
		LOG_WRN("Security change failed: %d", err);
	} else {
		LOG_INF("Security level changed to %d", level);
	}
}

static struct bt_conn_cb conn_callbacks = {
	.connected        = on_connected,
	.disconnected     = on_disconnected,
	.security_changed = on_security_changed,
};

/* -----------------------------------------------------------------------
 * Pairing callbacks
 * -------------------------------------------------------------------- */
static void on_pairing_complete(struct bt_conn *conn, bool bonded)
{
	LOG_INF("Pairing complete (bonded: %d)", bonded);
}

static void on_pairing_failed(struct bt_conn *conn,
			      enum bt_security_err reason)
{
	LOG_WRN("Pairing failed: %d", reason);
}

static const struct bt_conn_auth_info_cb auth_info_cb = {
	.pairing_complete = on_pairing_complete,
	.pairing_failed   = on_pairing_failed,
};

/* -----------------------------------------------------------------------
 * Public API
 * -------------------------------------------------------------------- */

int ble_manager_init(void)
{
	int err;

	memset(active_conns, 0, sizeof(active_conns));
	conn_count = 0;

	err = bt_enable(NULL);
	if (err) {
		LOG_ERR("bt_enable failed: %d", err);
		return err;
	}

	if (IS_ENABLED(CONFIG_SETTINGS)) {
		settings_load();
	}

	bt_conn_cb_register(&conn_callbacks);
	bt_conn_auth_info_cb_register(&auth_info_cb);

	/* Initialise GATT services */
	err = pet_tracker_service_init();
	if (err) {
		LOG_ERR("Pet tracker service init failed: %d", err);
		return err;
	}

	err = battery_service_init();
	if (err) {
		LOG_ERR("Battery service init failed: %d", err);
		return err;
	}

	err = device_info_service_init();
	if (err) {
		LOG_ERR("Device info service init failed: %d", err);
		return err;
	}

	LOG_INF("BLE manager initialised");
	return 0;
}

void ble_start_advertising(bool connectable)
{
	int err;
	const struct bt_le_adv_param *param =
		connectable ? &adv_param_connectable : &adv_param_beacon;

	bt_le_adv_stop();

	err = bt_le_adv_start(param, ad, ARRAY_SIZE(ad), NULL, 0);
	if (err && err != -EALREADY) {
		LOG_ERR("Advertising start failed: %d", err);
	} else {
		LOG_INF("BLE advertising started (%s)",
			connectable ? "connectable" : "beacon");
	}
}

void ble_stop_advertising(void)
{
	int err = bt_le_adv_stop();

	if (err) {
		LOG_WRN("bt_le_adv_stop: %d", err);
	}
}

bool ble_is_connected(void)
{
	return (conn_count > 0);
}

int ble_connection_count(void)
{
	return conn_count;
}

void ble_register_connection_callback(void (*cb)(bool connected))
{
	user_conn_cb = cb;
}

void ble_send_location_notification(const pet_location_t *loc)
{
	if (!loc) {
		return;
	}
	k_mutex_lock(&conn_mutex, K_FOREVER);
	for (int i = 0; i < CONFIG_BT_MAX_CONN; i++) {
		if (active_conns[i]) {
			pet_tracker_notify_location(active_conns[i], loc);
		}
	}
	k_mutex_unlock(&conn_mutex);
}

void ble_send_activity_notification(const pet_activity_data_t *act)
{
	if (!act) {
		return;
	}
	k_mutex_lock(&conn_mutex, K_FOREVER);
	for (int i = 0; i < CONFIG_BT_MAX_CONN; i++) {
		if (active_conns[i]) {
			pet_tracker_notify_activity(active_conns[i], act);
		}
	}
	k_mutex_unlock(&conn_mutex);
}

void ble_send_geofence_alert(const geofence_alert_t *alert)
{
	if (!alert) {
		return;
	}
	k_mutex_lock(&conn_mutex, K_FOREVER);
	for (int i = 0; i < CONFIG_BT_MAX_CONN; i++) {
		if (active_conns[i]) {
			pet_tracker_notify_geofence_alert(active_conns[i], alert);
		}
	}
	k_mutex_unlock(&conn_mutex);
}
