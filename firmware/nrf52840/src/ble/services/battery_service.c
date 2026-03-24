/*
 * Copyright (c) 2024 Smart Pet Collar Tracker
 * SPDX-License-Identifier: Apache-2.0
 *
 * Standard BLE Battery Service (UUID 0x180F) – implementation.
 */

#include "battery_service.h"

#include <zephyr/kernel.h>
#include <zephyr/bluetooth/bluetooth.h>
#include <zephyr/bluetooth/uuid.h>
#include <zephyr/bluetooth/gatt.h>
#include <zephyr/logging/log.h>

LOG_MODULE_REGISTER(battery_svc, LOG_LEVEL_DBG);

static uint8_t battery_level = 100U;
static uint8_t last_notified  = 255U; /* force first notification */

/* -----------------------------------------------------------------------
 * GATT handlers
 * -------------------------------------------------------------------- */
static ssize_t read_battery_level(struct bt_conn *conn,
				  const struct bt_gatt_attr *attr,
				  void *buf, uint16_t len, uint16_t offset)
{
	return bt_gatt_attr_read(conn, attr, buf, len, offset,
				 &battery_level, sizeof(battery_level));
}

static void battery_ccc_changed(const struct bt_gatt_attr *attr,
				uint16_t value)
{
	LOG_DBG("Battery notify %s",
		(value == BT_GATT_CCC_NOTIFY) ? "enabled" : "disabled");
}

/* -----------------------------------------------------------------------
 * GATT service definition
 * -------------------------------------------------------------------- */
BT_GATT_SERVICE_DEFINE(bas_svc,
	BT_GATT_PRIMARY_SERVICE(BT_UUID_BAS),
	BT_GATT_CHARACTERISTIC(BT_UUID_BAS_BATTERY_LEVEL,
			       BT_GATT_CHRC_READ | BT_GATT_CHRC_NOTIFY,
			       BT_GATT_PERM_READ,
			       read_battery_level, NULL, &battery_level),
	BT_GATT_CCC(battery_ccc_changed,
		    BT_GATT_PERM_READ | BT_GATT_PERM_WRITE),
);

/* -----------------------------------------------------------------------
 * Public API
 * -------------------------------------------------------------------- */

int battery_service_init(void)
{
	battery_level   = 100U;
	last_notified   = 255U;
	LOG_INF("Battery Service registered");
	return 0;
}

void battery_service_update(uint8_t percent)
{
	if (percent > 100U) {
		percent = 100U;
	}

	uint8_t old = battery_level;

	battery_level = percent;

	/* Notify on first call or when level changed by ≥5 % */
	uint8_t diff = (percent > last_notified) ?
		       (percent - last_notified) :
		       (last_notified - percent);

	if (diff >= 5U || last_notified == 255U) {
		last_notified = percent;
		int err = bt_gatt_notify(NULL,
					 &bas_svc.attrs[1],
					 &battery_level,
					 sizeof(battery_level));
		if (err && err != -ENOTCONN) {
			LOG_WRN("Battery notify error: %d", err);
		}
	}

	if (old != percent) {
		LOG_INF("Battery level: %u %%", percent);
	}
}
