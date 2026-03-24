/*
 * Copyright (c) 2024 Smart Pet Collar Tracker
 * SPDX-License-Identifier: Apache-2.0
 *
 * iBeacon manager – implementation.
 *
 * iBeacon advertising payload layout (inside AD type 0xFF / Manufacturer
 * Specific):
 *   Company ID (Apple) : 0x004C (LE) – 2 bytes
 *   iBeacon type       : 0x02        – 1 byte
 *   iBeacon length     : 0x15 (21)   – 1 byte
 *   Proximity UUID     : 16 bytes (big-endian)
 *   Major              : 2 bytes (big-endian)
 *   Minor              : 2 bytes (big-endian)
 *   TX Power           : 1 byte (signed, measured RSSI at 1 m)
 *   Total manufacturer data payload = 23 bytes
 */

#include "beacon_manager.h"
#include "../ble_manager.h"

#include <zephyr/kernel.h>
#include <zephyr/bluetooth/bluetooth.h>
#include <zephyr/logging/log.h>

LOG_MODULE_REGISTER(beacon_mgr, LOG_LEVEL_INF);

/* -----------------------------------------------------------------------
 * iBeacon payload
 * -------------------------------------------------------------------- */

/* Default proximity UUID: FDA50693-A4E2-4FB1-AFCF-C6EB07647825 */
static uint8_t beacon_uuid[16] = {
	0xFD, 0xA5, 0x06, 0x93,
	0xA4, 0xE2, 0x4F, 0xB1,
	0xAF, 0xCF, 0xC6, 0xEB,
	0x07, 0x64, 0x78, 0x25,
};

static uint16_t beacon_major = 0x0001;
static uint16_t beacon_minor = 0x0001;
static int8_t   beacon_tx_power = -59; /* calibrated RSSI at 1 m */

/* Build the 25-byte manufacturer-specific AD payload */
static uint8_t mfr_data[25];

static void build_mfr_data(void)
{
	uint8_t *p = mfr_data;

	/* Apple company ID, little-endian */
	*p++ = 0x4C;
	*p++ = 0x00;
	/* iBeacon subtype + length */
	*p++ = 0x02;
	*p++ = 0x15;
	/* Proximity UUID (big-endian) */
	memcpy(p, beacon_uuid, 16);
	p += 16;
	/* Major (big-endian) */
	*p++ = (uint8_t)(beacon_major >> 8);
	*p++ = (uint8_t)(beacon_major & 0xFF);
	/* Minor (big-endian) */
	*p++ = (uint8_t)(beacon_minor >> 8);
	*p++ = (uint8_t)(beacon_minor & 0xFF);
	/* TX Power */
	*p++ = (uint8_t)beacon_tx_power;
}

static const struct bt_data beacon_ad[] = {
	BT_DATA_BYTES(BT_DATA_FLAGS, BT_LE_AD_NO_BREDR),
	BT_DATA(BT_DATA_MANUFACTURER_DATA, mfr_data, sizeof(mfr_data)),
};

static const struct bt_le_adv_param beacon_adv_param =
	BT_LE_ADV_PARAM_INIT(BT_LE_ADV_OPT_USE_IDENTITY,
			     BT_GAP_ADV_SLOW_INT_MIN,
			     BT_GAP_ADV_SLOW_INT_MAX,
			     NULL);

/* -----------------------------------------------------------------------
 * Timer – alternate connectable ↔ beacon every 10 s when not connected
 * -------------------------------------------------------------------- */
#define BEACON_INTERVAL_S  10U

static struct k_timer beacon_timer;
static bool           beaconing;

static void beacon_timer_cb(struct k_timer *timer)
{
	if (ble_is_connected()) {
		/* Stop beaconing while a peer is connected */
		if (beaconing) {
			beacon_stop();
		}
		return;
	}

	if (beaconing) {
		/* Switch to connectable advertising */
		beaconing = false;
		LOG_DBG("Beacon → connectable");
		ble_start_advertising(true);
	} else {
		/* Switch to beacon advertising */
		beaconing = true;
		LOG_DBG("Connectable → beacon");
		beacon_start();
	}
}

/* -----------------------------------------------------------------------
 * Public API
 * -------------------------------------------------------------------- */

int beacon_manager_init(void)
{
	build_mfr_data();
	beaconing = false;
	k_timer_init(&beacon_timer, beacon_timer_cb, NULL);
	k_timer_start(&beacon_timer,
		      K_SECONDS(BEACON_INTERVAL_S),
		      K_SECONDS(BEACON_INTERVAL_S));
	LOG_INF("Beacon manager initialised");
	return 0;
}

void beacon_start(void)
{
	build_mfr_data();
	bt_le_adv_stop();

	int err = bt_le_adv_start(&beacon_adv_param,
				  beacon_ad, ARRAY_SIZE(beacon_ad),
				  NULL, 0);
	if (err && err != -EALREADY) {
		LOG_ERR("Beacon adv start failed: %d", err);
	} else {
		LOG_INF("iBeacon advertising started");
		beaconing = true;
	}
}

void beacon_stop(void)
{
	bt_le_adv_stop();
	beaconing = false;
	LOG_INF("Beacon advertising stopped");
}

void beacon_set_params(const uint8_t uuid[16],
		       uint16_t major,
		       uint16_t minor)
{
	memcpy(beacon_uuid, uuid, 16);
	beacon_major = major;
	beacon_minor = minor;
}
