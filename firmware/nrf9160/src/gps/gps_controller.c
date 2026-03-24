/*
 * Copyright (c) 2024 Smart Pet Collar Tracker
 * SPDX-License-Identifier: Apache-2.0
 *
 * GPS controller – wraps nrf_modem_gnss for periodic PVT-based fix
 * acquisition with A-GPS support and wake-on-motion integration.
 */

#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>
#include <nrf_modem_gnss.h>
#include <string.h>

#include "gps_controller.h"
#include "config.h"
#include "pet_data.h"

LOG_MODULE_REGISTER(gps_controller, LOG_LEVEL_INF);

/* ── Internal state ─────────────────────────────────────────────────────── */

static void (*fix_cb)(const struct pet_location *loc);
static pet_location_t   last_fix;
static bool             has_valid_fix;
static uint32_t         fix_interval_s = GPS_FIX_INTERVAL_ACTIVE_S;
static atomic_t         gnss_running   = ATOMIC_INIT(0);

/* ── Work items ─────────────────────────────────────────────────────────── */

static struct k_work_delayable periodic_fix_work;
static struct k_work            fix_ready_work;

/* PVT data is set in the GNSS event handler (ISR context) and consumed
 * by the work handler (thread context). */
static struct nrf_modem_gnss_pvt_data_frame pvt_data;
static K_MUTEX_DEFINE(pvt_mutex);

/* ── Helpers ────────────────────────────────────────────────────────────── */

static void pvt_to_pet_location(const struct nrf_modem_gnss_pvt_data_frame *pvt,
				pet_location_t *loc)
{
	loc->latitude_udeg  = (int32_t)(pvt->latitude  * 1e6);
	loc->longitude_udeg = (int32_t)(pvt->longitude * 1e6);
	loc->altitude_mm    = (int32_t)(pvt->altitude  * 1000.0f);
	loc->speed_mmps     = (uint32_t)(pvt->speed     * 1000.0f);
	loc->heading_cdeg   = (uint16_t)(pvt->heading   * 100.0f);
	loc->accuracy_mm    = (uint32_t)(pvt->accuracy  * 1000.0f);
	loc->fix_quality    = (pvt->flags & NRF_MODEM_GNSS_PVT_FLAG_FIX_VALID) ? 1U : 0U;
	loc->satellites     = pvt->sv_count;

	/* Build Unix timestamp from the PVT datetime */
	struct tm t = {
		.tm_year = pvt->datetime.year - 1900,
		.tm_mon  = pvt->datetime.month - 1,
		.tm_mday = pvt->datetime.day,
		.tm_hour = pvt->datetime.hour,
		.tm_min  = pvt->datetime.minute,
		.tm_sec  = pvt->datetime.seconds,
	};
	loc->timestamp_s = (uint32_t)mktime(&t);
}

/* ── GNSS event handler (called from modem library context) ─────────────── */

static void gnss_event_handler(int event)
{
	switch (event) {
	case NRF_MODEM_GNSS_EVT_PVT:
		k_mutex_lock(&pvt_mutex, K_FOREVER);
		nrf_modem_gnss_read(&pvt_data, sizeof(pvt_data),
				    NRF_MODEM_GNSS_DATA_PVT);
		k_mutex_unlock(&pvt_mutex);

		if (pvt_data.flags & NRF_MODEM_GNSS_PVT_FLAG_FIX_VALID) {
			k_work_submit(&fix_ready_work);
		}
		break;

	case NRF_MODEM_GNSS_EVT_AGPS_REQ:
		LOG_INF("A-GPS assistance data requested by modem");
		break;

	case NRF_MODEM_GNSS_EVT_BLOCKED:
		LOG_WRN("GNSS blocked by LTE activity");
		break;

	case NRF_MODEM_GNSS_EVT_UNBLOCKED:
		LOG_DBG("GNSS unblocked");
		break;

	default:
		break;
	}
}

/* ── Work handlers ──────────────────────────────────────────────────────── */

static void fix_ready_handler(struct k_work *work)
{
	pet_location_t loc;

	k_mutex_lock(&pvt_mutex, K_FOREVER);
	pvt_to_pet_location(&pvt_data, &loc);
	k_mutex_unlock(&pvt_mutex);

	if (loc.accuracy_mm > GPS_MIN_ACCURACY_MM) {
		LOG_DBG("Fix accuracy too low: %u mm", loc.accuracy_mm);
		return;
	}

	last_fix       = loc;
	has_valid_fix  = true;

	LOG_INF("GPS fix: lat=%d lon=%d acc=%u mm sats=%u",
		loc.latitude_udeg, loc.longitude_udeg,
		loc.accuracy_mm, loc.satellites);

	if (fix_cb) {
		fix_cb(&loc);
	}

	/* In non-tracking modes stop GNSS after a valid fix to save power */
	if (fix_interval_s > GPS_FIX_INTERVAL_TRACKING_S) {
		nrf_modem_gnss_stop();
		atomic_set(&gnss_running, 0);
	}
}

static void periodic_fix_handler(struct k_work *work)
{
	int ret;

	if (fix_interval_s == 0) {
		return;
	}

	if (!atomic_get(&gnss_running)) {
		ret = nrf_modem_gnss_start();
		if (ret < 0) {
			LOG_ERR("GNSS start failed: %d", ret);
		} else {
			atomic_set(&gnss_running, 1);
			LOG_DBG("GNSS started for periodic fix");
		}
	}

	k_work_schedule(&periodic_fix_work, K_SECONDS(fix_interval_s));
}

/* ── Public API ─────────────────────────────────────────────────────────── */

int gps_controller_init(void)
{
	int ret;

	ret = nrf_modem_gnss_event_handler_set(gnss_event_handler);
	if (ret < 0) {
		LOG_ERR("GNSS event handler set failed: %d", ret);
		return ret;
	}

	/* Configure PVT output; 1-second fix rate attempt */
	ret = nrf_modem_gnss_fix_interval_set(1);
	if (ret < 0) {
		LOG_ERR("GNSS fix interval set failed: %d", ret);
		return ret;
	}

	/* Retry timeout – give up after GPS_FIX_TIMEOUT_S seconds */
	ret = nrf_modem_gnss_fix_retry_set(GPS_FIX_TIMEOUT_S);
	if (ret < 0) {
		LOG_ERR("GNSS fix retry set failed: %d", ret);
		return ret;
	}

	/* Use PVT output (not NMEA) */
	ret = nrf_modem_gnss_nmea_mask_set(0);
	if (ret < 0) {
		LOG_ERR("GNSS NMEA mask set failed: %d", ret);
		return ret;
	}

	k_work_init(&fix_ready_work, fix_ready_handler);
	k_work_init_delayable(&periodic_fix_work, periodic_fix_handler);

	LOG_INF("GPS controller initialised");
	return 0;
}

int gps_controller_start(void)
{
	if (fix_interval_s == 0) {
		LOG_INF("GPS disabled (interval=0)");
		return 0;
	}

	/* Schedule immediately */
	k_work_schedule(&periodic_fix_work, K_NO_WAIT);
	LOG_INF("GPS periodic fix started, interval=%u s", fix_interval_s);
	return 0;
}

int gps_controller_stop(void)
{
	int ret;

	k_work_cancel_delayable(&periodic_fix_work);

	if (atomic_get(&gnss_running)) {
		ret = nrf_modem_gnss_stop();
		if (ret < 0) {
			LOG_ERR("GNSS stop failed: %d", ret);
			return ret;
		}
		atomic_set(&gnss_running, 0);
	}

	LOG_INF("GPS controller stopped");
	return 0;
}

void gps_set_fix_interval(uint32_t interval_s)
{
	fix_interval_s = interval_s;
	LOG_INF("GPS fix interval set to %u s", interval_s);

	if (interval_s == 0) {
		gps_controller_stop();
		return;
	}

	/* Re-schedule with new interval */
	k_work_reschedule(&periodic_fix_work, K_SECONDS(interval_s));
}

void gps_register_fix_callback(void (*cb)(const struct pet_location *loc))
{
	fix_cb = cb;
}

int gps_inject_agps_data(const uint8_t *data, size_t len)
{
	if (!data || len == 0) {
		return -EINVAL;
	}

	int ret = nrf_modem_gnss_agps_write(data, len,
					    NRF_MODEM_GNSS_AGPS_GPS_UTC_PARAMETERS);
	if (ret < 0) {
		LOG_ERR("A-GPS inject failed: %d", ret);
	} else {
		LOG_INF("A-GPS data injected: %zu bytes", len);
	}
	return ret;
}

int gps_get_last_fix(struct pet_location *loc)
{
	if (!has_valid_fix) {
		return -ENODATA;
	}
	if (!loc) {
		return -EINVAL;
	}
	*loc = last_fix;
	return 0;
}

int gps_trigger_single_fix(void)
{
	int ret;

	if (!atomic_get(&gnss_running)) {
		ret = nrf_modem_gnss_start();
		if (ret < 0) {
			LOG_ERR("GNSS single-shot start failed: %d", ret);
			return ret;
		}
		atomic_set(&gnss_running, 1);
		LOG_DBG("GNSS single-shot triggered");
	}
	return 0;
}
