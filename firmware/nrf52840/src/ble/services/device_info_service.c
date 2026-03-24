/*
 * Copyright (c) 2024 Smart Pet Collar Tracker
 * SPDX-License-Identifier: Apache-2.0
 *
 * BLE Device Information Service (DIS) – implementation.
 *
 * The DIS strings are provided via Kconfig (CONFIG_BT_DIS_*).  This module
 * simply ensures that the service is registered and logs its presence.
 */

#include "device_info_service.h"

#include <zephyr/kernel.h>
#include <zephyr/bluetooth/gatt.h>
#include <zephyr/logging/log.h>

LOG_MODULE_REGISTER(device_info_svc, LOG_LEVEL_INF);

int device_info_service_init(void)
{
	/*
	 * The Zephyr BT_DIS subsystem registers all DIS characteristics
	 * automatically when CONFIG_BT_DIS=y is set in prj.conf.
	 * Nothing else to do here.
	 */
	LOG_INF("Device Information Service registered");
	LOG_INF("  Manufacturer : %s", CONFIG_BT_DIS_MANUF);
	LOG_INF("  Model        : %s", CONFIG_BT_DIS_MODEL);
	LOG_INF("  FW revision  : %s", CONFIG_BT_DIS_FW_REV);
	LOG_INF("  HW revision  : %s", CONFIG_BT_DIS_HW_REV);
	return 0;
}
