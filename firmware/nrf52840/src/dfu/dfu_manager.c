/*
 * Copyright (c) 2024 Smart Pet Collar Tracker
 * SPDX-License-Identifier: Apache-2.0
 *
 * DFU Manager – implementation.
 *
 * Uses Zephyr MCUmgr with the BLE SMP transport.  On startup the manager
 * auto-confirms the running image so that MCUboot does not revert to the
 * previous version after the configurable number of boot attempts.
 */

#include "dfu_manager.h"

#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>
#include <zephyr/dfu/mcuboot.h>
#include <zephyr/mgmt/mcumgr/mgmt/mgmt.h>
#include <zephyr/mgmt/mcumgr/transport/smp_bt.h>
#include <zephyr/mgmt/mcumgr/grp/img_mgmt/img_mgmt.h>
#include <zephyr/mgmt/mcumgr/grp/os_mgmt/os_mgmt.h>

LOG_MODULE_REGISTER(dfu_mgr, LOG_LEVEL_INF);

static void (*progress_cb)(uint8_t percent);

/* -----------------------------------------------------------------------
 * MCUmgr image upload hook
 * -------------------------------------------------------------------- */
static int img_upload_start_cb(const struct img_mgmt_upload_req *req,
			       const struct img_mgmt_state *state)
{
	LOG_INF("DFU upload started (size: %u bytes)", req->image_size);
	if (progress_cb) {
		progress_cb(0);
	}
	return 0; /* allow */
}

static int img_upload_done_cb(const struct img_mgmt_upload_req *req,
			      const struct img_mgmt_state *state,
			      bool last)
{
	if (last) {
		uint8_t pct = 100U;

		LOG_INF("DFU upload complete");
		if (progress_cb) {
			progress_cb(pct);
		}
	} else if (req->image_size > 0) {
		uint8_t pct = (uint8_t)((state->bytes_written * 100U) /
					 req->image_size);
		if (progress_cb) {
			progress_cb(pct);
		}
	}
	return 0;
}

static const struct img_mgmt_dfu_callbacks dfu_cbs = {
	.dfu_started_cb   = img_upload_start_cb,
	.dfu_completed_cb = img_upload_done_cb,
};

/* -----------------------------------------------------------------------
 * Public API
 * -------------------------------------------------------------------- */

int dfu_manager_init(void)
{
	int err;

	/* Register MCUmgr groups */
	os_mgmt_register_group();
	img_mgmt_register_group();

	/* Register image upload hooks */
	img_mgmt_set_dfu_callbacks(&dfu_cbs);

	/* Start the SMP BLE transport */
	err = smp_bt_register();
	if (err) {
		LOG_ERR("SMP BLE register failed: %d", err);
		return err;
	}

	/* Auto-confirm the currently running image */
	if (boot_is_img_confirmed()) {
		LOG_INF("Image already confirmed");
	} else {
		err = boot_write_img_confirmed();
		if (err) {
			LOG_WRN("Failed to confirm image: %d", err);
		} else {
			LOG_INF("Running image confirmed");
		}
	}

	LOG_INF("DFU manager initialised (SMP over BLE)");
	return 0;
}

bool dfu_is_update_pending(void)
{
	/* If image is not yet confirmed, an update is pending test */
	return !boot_is_img_confirmed();
}

int dfu_confirm_image(void)
{
	int err = boot_write_img_confirmed();

	if (err) {
		LOG_ERR("dfu_confirm_image failed: %d", err);
	} else {
		LOG_INF("Image confirmed");
	}
	return err;
}

void dfu_revert_image(void)
{
	LOG_WRN("Requesting image revert on next reboot");
	boot_request_upgrade(BOOT_UPGRADE_TEST);
}

void dfu_register_progress_callback(void (*cb)(uint8_t percent))
{
	progress_cb = cb;
}
