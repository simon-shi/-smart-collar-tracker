/*
 * Copyright (c) 2024 Smart Pet Collar Tracker
 * SPDX-License-Identifier: Apache-2.0
 *
 * Custom Pet Tracker GATT Service – implementation.
 */

#include "pet_tracker_service.h"

#include <zephyr/kernel.h>
#include <zephyr/bluetooth/bluetooth.h>
#include <zephyr/bluetooth/uuid.h>
#include <zephyr/bluetooth/gatt.h>
#include <zephyr/logging/log.h>

#include "../../../common/include/pet_data.h"
#include "../../../common/include/config.h"

LOG_MODULE_REGISTER(pet_tracker_svc, LOG_LEVEL_DBG);

/* -----------------------------------------------------------------------
 * UUID definitions
 * -------------------------------------------------------------------- */
#define BT_UUID_PET_TRACKER_SVC_VAL \
	BT_UUID_128_ENCODE(0x12345678, 0x1234, 0x5678, 0x1234, 0x56789abcdef0)
#define BT_UUID_PET_LOC_VAL \
	BT_UUID_128_ENCODE(0x12345678, 0x1234, 0x5678, 0x1234, 0x56789abcdef1)
#define BT_UUID_PET_ACT_VAL \
	BT_UUID_128_ENCODE(0x12345678, 0x1234, 0x5678, 0x1234, 0x56789abcdef2)
#define BT_UUID_PET_FENCE_VAL \
	BT_UUID_128_ENCODE(0x12345678, 0x1234, 0x5678, 0x1234, 0x56789abcdef3)
#define BT_UUID_PET_CTRL_VAL \
	BT_UUID_128_ENCODE(0x12345678, 0x1234, 0x5678, 0x1234, 0x56789abcdef4)
#define BT_UUID_PET_STATUS_VAL \
	BT_UUID_128_ENCODE(0x12345678, 0x1234, 0x5678, 0x1234, 0x56789abcdef5)
#define BT_UUID_PET_SYNC_VAL \
	BT_UUID_128_ENCODE(0x12345678, 0x1234, 0x5678, 0x1234, 0x56789abcdef6)

#define BT_UUID_PET_TRACKER_SVC  BT_UUID_DECLARE_128(BT_UUID_PET_TRACKER_SVC_VAL)
#define BT_UUID_PET_LOC          BT_UUID_DECLARE_128(BT_UUID_PET_LOC_VAL)
#define BT_UUID_PET_ACT          BT_UUID_DECLARE_128(BT_UUID_PET_ACT_VAL)
#define BT_UUID_PET_FENCE        BT_UUID_DECLARE_128(BT_UUID_PET_FENCE_VAL)
#define BT_UUID_PET_CTRL         BT_UUID_DECLARE_128(BT_UUID_PET_CTRL_VAL)
#define BT_UUID_PET_STATUS       BT_UUID_DECLARE_128(BT_UUID_PET_STATUS_VAL)
#define BT_UUID_PET_SYNC         BT_UUID_DECLARE_128(BT_UUID_PET_SYNC_VAL)

/* -----------------------------------------------------------------------
 * Module state
 * -------------------------------------------------------------------- */
static void (*ctrl_write_cb)(const uint8_t *data, uint16_t len);

static uint8_t  loc_buf[PET_LOCATION_SERIALISED_SIZE];
static uint8_t  act_buf[PET_ACTIVITY_SERIALISED_SIZE];
static uint8_t  fence_buf[PET_GEOFENCE_SERIALISED_SIZE];
static uint8_t  status_buf[PET_DEVICE_STATUS_SERIALISED_SIZE];

/* -----------------------------------------------------------------------
 * GATT characteristic handlers
 * -------------------------------------------------------------------- */
static ssize_t read_status(struct bt_conn *conn,
			   const struct bt_gatt_attr *attr,
			   void *buf, uint16_t len, uint16_t offset)
{
	return bt_gatt_attr_read(conn, attr, buf, len, offset,
				 status_buf, sizeof(status_buf));
}

static ssize_t write_control(struct bt_conn *conn,
			     const struct bt_gatt_attr *attr,
			     const void *buf, uint16_t len,
			     uint16_t offset, uint8_t flags)
{
	if (offset != 0 || len == 0) {
		return BT_GATT_ERR(BT_ATT_ERR_INVALID_OFFSET);
	}

	LOG_DBG("Control write: %u bytes", len);

	if (ctrl_write_cb) {
		ctrl_write_cb((const uint8_t *)buf, len);
	}

	return len;
}

static void loc_ccc_changed(const struct bt_gatt_attr *attr, uint16_t value)
{
	LOG_DBG("Location notify %s",
		(value == BT_GATT_CCC_NOTIFY) ? "enabled" : "disabled");
}

static void act_ccc_changed(const struct bt_gatt_attr *attr, uint16_t value)
{
	LOG_DBG("Activity notify %s",
		(value == BT_GATT_CCC_NOTIFY) ? "enabled" : "disabled");
}

static void fence_ccc_changed(const struct bt_gatt_attr *attr, uint16_t value)
{
	LOG_DBG("Geofence notify %s",
		(value == BT_GATT_CCC_NOTIFY) ? "enabled" : "disabled");
}

static void sync_ccc_changed(const struct bt_gatt_attr *attr, uint16_t value)
{
	LOG_DBG("Offline sync notify %s",
		(value == BT_GATT_CCC_NOTIFY) ? "enabled" : "disabled");
}

/* -----------------------------------------------------------------------
 * GATT service definition
 * -------------------------------------------------------------------- */
BT_GATT_SERVICE_DEFINE(pet_tracker_svc,
	BT_GATT_PRIMARY_SERVICE(BT_UUID_PET_TRACKER_SVC),

	/* Location – Notify */
	BT_GATT_CHARACTERISTIC(BT_UUID_PET_LOC,
			       BT_GATT_CHRC_NOTIFY,
			       BT_GATT_PERM_NONE,
			       NULL, NULL, loc_buf),
	BT_GATT_CCC(loc_ccc_changed,
		    BT_GATT_PERM_READ | BT_GATT_PERM_WRITE),

	/* Activity – Notify */
	BT_GATT_CHARACTERISTIC(BT_UUID_PET_ACT,
			       BT_GATT_CHRC_NOTIFY,
			       BT_GATT_PERM_NONE,
			       NULL, NULL, act_buf),
	BT_GATT_CCC(act_ccc_changed,
		    BT_GATT_PERM_READ | BT_GATT_PERM_WRITE),

	/* Geofence Alert – Notify */
	BT_GATT_CHARACTERISTIC(BT_UUID_PET_FENCE,
			       BT_GATT_CHRC_NOTIFY,
			       BT_GATT_PERM_NONE,
			       NULL, NULL, fence_buf),
	BT_GATT_CCC(fence_ccc_changed,
		    BT_GATT_PERM_READ | BT_GATT_PERM_WRITE),

	/* Device Control – Write */
	BT_GATT_CHARACTERISTIC(BT_UUID_PET_CTRL,
			       BT_GATT_CHRC_WRITE | BT_GATT_CHRC_WRITE_WITHOUT_RESP,
			       BT_GATT_PERM_WRITE,
			       NULL, write_control, NULL),

	/* Device Status – Read */
	BT_GATT_CHARACTERISTIC(BT_UUID_PET_STATUS,
			       BT_GATT_CHRC_READ,
			       BT_GATT_PERM_READ,
			       read_status, NULL, status_buf),

	/* Offline Sync – Notify */
	BT_GATT_CHARACTERISTIC(BT_UUID_PET_SYNC,
			       BT_GATT_CHRC_NOTIFY,
			       BT_GATT_PERM_NONE,
			       NULL, NULL, NULL),
	BT_GATT_CCC(sync_ccc_changed,
		    BT_GATT_PERM_READ | BT_GATT_PERM_WRITE),
);

/* -----------------------------------------------------------------------
 * Public API
 * -------------------------------------------------------------------- */

int pet_tracker_service_init(void)
{
	memset(status_buf, 0, sizeof(status_buf));
	LOG_INF("Pet Tracker GATT service registered");
	return 0;
}

int pet_tracker_notify_location(struct bt_conn *conn,
				const pet_location_t *loc)
{
	if (!conn || !loc) {
		return -EINVAL;
	}

	uint8_t buf[PET_LOCATION_SERIALISED_SIZE];
	int len = pet_location_serialise(buf, loc);

	if (len < 0) {
		return len;
	}

	/* Attribute index for Location char value: index 1 (0-based after primary) */
	return bt_gatt_notify(conn,
			      &pet_tracker_svc.attrs[1],
			      buf, (uint16_t)len);
}

int pet_tracker_notify_activity(struct bt_conn *conn,
				const pet_activity_data_t *act)
{
	if (!conn || !act) {
		return -EINVAL;
	}

	uint8_t buf[PET_ACTIVITY_SERIALISED_SIZE];
	int len = pet_activity_serialise(buf, act);

	if (len < 0) {
		return len;
	}

	return bt_gatt_notify(conn,
			      &pet_tracker_svc.attrs[4],
			      buf, (uint16_t)len);
}

int pet_tracker_notify_geofence_alert(struct bt_conn *conn,
				      const geofence_alert_t *alert)
{
	if (!conn || !alert) {
		return -EINVAL;
	}

	uint8_t buf[PET_GEOFENCE_SERIALISED_SIZE];
	int len = pet_geofence_serialise(buf, alert);

	if (len < 0) {
		return len;
	}

	return bt_gatt_notify(conn,
			      &pet_tracker_svc.attrs[7],
			      buf, (uint16_t)len);
}

int pet_tracker_update_status(const device_status_t *status)
{
	if (!status) {
		return -EINVAL;
	}

	/* power_mode(1) + fw(3) + rsrp(2) + rsrq(2) + battery(8) + uptime(4) */
	uint8_t *p = status_buf;

	*p++ = (uint8_t)status->power_mode;
	*p++ = status->fw_version_major;
	*p++ = status->fw_version_minor;
	*p++ = status->fw_version_patch;
	*p++ = (uint8_t)(status->rsrp_dbm & 0xFF);
	*p++ = (uint8_t)((status->rsrp_dbm >> 8) & 0xFF);
	*p++ = (uint8_t)(status->rsrq_db & 0xFF);
	*p++ = (uint8_t)((status->rsrq_db >> 8) & 0xFF);

	pet_battery_serialise(p, &status->battery);
	p += PET_BATTERY_SERIALISED_SIZE;

	*p++ = (uint8_t)(status->uptime_s & 0xFF);
	*p++ = (uint8_t)((status->uptime_s >> 8)  & 0xFF);
	*p++ = (uint8_t)((status->uptime_s >> 16) & 0xFF);
	*p++ = (uint8_t)((status->uptime_s >> 24) & 0xFF);

	return 0;
}

void pet_tracker_register_control_callback(
	void (*cb)(const uint8_t *data, uint16_t len))
{
	ctrl_write_cb = cb;
}
