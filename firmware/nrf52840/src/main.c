/*
 * Copyright (c) 2024 Smart Pet Collar Tracker
 * SPDX-License-Identifier: Apache-2.0
 *
 * nRF52840 BLE application – main entry point.
 */

#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>
#include <zephyr/sys/reboot.h>
#include <zephyr/drivers/watchdog.h>
#include <zephyr/device.h>

#include "uart_bridge/uart_bridge.h"
#include "flash/flash_manager.h"
#include "ble/ble_manager.h"
#include "charge/charge_manager.h"
#include "dfu/dfu_manager.h"
#include "ble/beacon/beacon_manager.h"

LOG_MODULE_REGISTER(main, LOG_LEVEL_INF);

/* Watchdog */
#define WDT_NODE DT_ALIAS(watchdog0)

static const struct device *wdt_dev;
static int wdt_channel_id = -1;

static void wdt_callback(const struct device *dev, int channel_id)
{
	LOG_ERR("Watchdog fired – resetting");
	sys_reboot(SYS_REBOOT_COLD);
}

static int watchdog_init(void)
{
	struct wdt_timeout_cfg wdt_cfg = {
		.window  = { .min = 0U, .max = 30000U },
		.callback = wdt_callback,
		.flags   = WDT_FLAG_RESET_SOC,
	};

	if (!device_is_ready(wdt_dev)) {
		LOG_WRN("WDT device not ready – skipping");
		return 0;
	}

	wdt_channel_id = wdt_install_timeout(wdt_dev, &wdt_cfg);
	if (wdt_channel_id < 0) {
		LOG_ERR("Failed to install WDT timeout: %d", wdt_channel_id);
		return wdt_channel_id;
	}

	return wdt_setup(wdt_dev, WDT_OPT_PAUSE_HALTED_BY_DBG);
}

static void feed_watchdog(void)
{
	if (wdt_dev && wdt_channel_id >= 0) {
		wdt_feed(wdt_dev, wdt_channel_id);
	}
}

int main(void)
{
	int err;

	LOG_INF("Smart Collar nRF52840 firmware v%d.%d.%d starting",
		FW_VERSION_MAJOR, FW_VERSION_MINOR, FW_VERSION_PATCH);

	/* Watchdog */
	wdt_dev = DEVICE_DT_GET_OR_NULL(WDT_NODE);
	err = watchdog_init();
	if (err) {
		LOG_WRN("Watchdog init failed: %d", err);
	}

	/* UART bridge to nRF9160 – init first so other modules can queue msgs */
	err = uart_bridge_init();
	if (err) {
		LOG_ERR("UART bridge init failed: %d", err);
	}

	/* External NOR flash ring buffer */
	err = flash_manager_init();
	if (err) {
		LOG_ERR("Flash manager init failed: %d", err);
	}

	/* Charge / connector detection */
	err = charge_manager_init();
	if (err) {
		LOG_ERR("Charge manager init failed: %d", err);
	}

	/* BLE stack */
	err = ble_manager_init();
	if (err) {
		LOG_ERR("BLE manager init failed: %d", err);
	}

	/* Beacon (iBeacon) manager */
	err = beacon_manager_init();
	if (err) {
		LOG_ERR("Beacon manager init failed: %d", err);
	}

	/* DFU */
	err = dfu_manager_init();
	if (err) {
		LOG_ERR("DFU manager init failed: %d", err);
	}

	/* Start BLE advertising */
	ble_start_advertising(true);

	LOG_INF("All modules initialised – entering main loop");

	while (true) {
		feed_watchdog();
		k_sleep(K_SECONDS(10));
	}

	return 0;
}
