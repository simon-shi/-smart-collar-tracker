/*
 * Copyright (c) 2024 Smart Pet Collar Tracker
 * SPDX-License-Identifier: Apache-2.0
 *
 * LTE manager – LTE-M / NB-IoT modem connection management with PSM,
 * eDRX, and exponential back-off reconnection.
 */

#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>
#include <modem/lte_lc.h>
#include <modem/modem_info.h>
#include <nrf_modem_at.h>
#include <string.h>
#include <errno.h>
#include <limits.h>

#include "lte_manager.h"
#include "config.h"

LOG_MODULE_REGISTER(lte_manager, LOG_LEVEL_INF);

/* ── Reconnect back-off ──────────────────────────────────────────────────*/
#define BACKOFF_INITIAL_S   4
#define BACKOFF_MAX_S       3840   /* ~64 minutes */

/* ── Internal state ──────────────────────────────────────────────────────*/
static void (*event_cb)(enum lte_event);
static atomic_t connected     = ATOMIC_INIT(0);
static atomic_t connecting    = ATOMIC_INIT(0);
static uint32_t backoff_s     = BACKOFF_INITIAL_S;
static int      consec_failures;
static int      rsrp_cached   = INT_MIN;
static int      rsrq_cached   = INT_MIN;

/* ── Work items ──────────────────────────────────────────────────────────*/
static struct k_work_delayable reconnect_work;

/* ── PSM / eDRX AT commands ──────────────────────────────────────────────*/

/* PSM: TAU = 12 h (T3412 = "01000110" = 0x46), active time = 10 s
 * (T3324 = "00000101" = 0x05) */
#define PSM_TAU_VALUE    "\"01000110\""
#define PSM_ACTIVE_VALUE "\"00000101\""

/* eDRX: LTE-M cycle 40.96 s (value "0101"), NB-IoT same */
#define EDRX_LTE_M_VALUE "\"0101\""
#define EDRX_NB_IOT_VALUE "\"0101\""

static int configure_psm(void)
{
	int ret = nrf_modem_at_printf("AT+CPSMS=1,,," PSM_TAU_VALUE "," PSM_ACTIVE_VALUE);
	if (ret < 0) {
		LOG_ERR("PSM configure failed: %d", ret);
	} else {
		LOG_INF("PSM configured: TAU=%s active=%s",
			PSM_TAU_VALUE, PSM_ACTIVE_VALUE);
	}
	return ret;
}

static int configure_edrx(void)
{
	/* LTE-M */
	int ret = nrf_modem_at_printf("AT+CEDRXS=2,4," EDRX_LTE_M_VALUE);
	if (ret < 0) {
		LOG_WRN("eDRX LTE-M configure failed: %d", ret);
	}
	/* NB-IoT */
	ret = nrf_modem_at_printf("AT+CEDRXS=2,5," EDRX_NB_IOT_VALUE);
	if (ret < 0) {
		LOG_WRN("eDRX NB-IoT configure failed: %d", ret);
	}
	LOG_INF("eDRX configured");
	return 0;
}

/* ── LTE LC event handler ────────────────────────────────────────────────*/

static void lte_lc_event_handler(const struct lte_lc_evt *const evt)
{
	switch (evt->type) {
	case LTE_LC_EVT_NW_REG_STATUS:
		switch (evt->nw_reg_status) {
		case LTE_LC_NW_REG_REGISTERED_HOME:
		case LTE_LC_NW_REG_REGISTERED_ROAMING:
			LOG_INF("LTE registered (%s)",
				evt->nw_reg_status == LTE_LC_NW_REG_REGISTERED_HOME
				? "home" : "roaming");
			atomic_set(&connected, 1);
			atomic_set(&connecting, 0);
			backoff_s       = BACKOFF_INITIAL_S;
			consec_failures = 0;
			if (event_cb) {
				event_cb(LTE_EVENT_CONNECTED);
			}
			break;
		case LTE_LC_NW_REG_NOT_REGISTERED:
		case LTE_LC_NW_REG_REGISTRATION_DENIED:
		case LTE_LC_NW_REG_UNKNOWN:
			if (atomic_get(&connected)) {
				atomic_set(&connected, 0);
				if (event_cb) {
					event_cb(LTE_EVENT_DISCONNECTED);
				}
			}
			if (!atomic_get(&connecting)) {
				/* Schedule reconnect with back-off */
				consec_failures++;
				LOG_WRN("LTE not registered – retry in %u s (fail #%d)",
					backoff_s, consec_failures);
				k_work_schedule(&reconnect_work,
						K_SECONDS(backoff_s));
				backoff_s = MIN(backoff_s * 2U, BACKOFF_MAX_S);
			}
			break;
		case LTE_LC_NW_REG_SEARCHING:
			if (event_cb) {
				event_cb(LTE_EVENT_CONNECTING);
			}
			break;
		default:
			break;
		}
		break;

	case LTE_LC_EVT_PSM_UPDATE:
		LOG_INF("PSM: TAU=%d s, active=%d s",
			evt->psm_cfg.tau, evt->psm_cfg.active_time);
		if (event_cb) {
			event_cb(LTE_EVENT_PSM_UPDATE);
		}
		break;

	case LTE_LC_EVT_EDRX_UPDATE:
		LOG_INF("eDRX: cycle=%.2f s, PTW=%.2f s",
			(double)evt->edrx_cfg.edrx,
			(double)evt->edrx_cfg.ptw);
		if (event_cb) {
			event_cb(LTE_EVENT_EDRX_UPDATE);
		}
		break;

	case LTE_LC_EVT_CELL_UPDATE:
		LOG_DBG("Cell update: id=%u tac=%u",
			evt->cell.id, evt->cell.tac);
		if (event_cb) {
			event_cb(LTE_EVENT_CELL_UPDATE);
		}
		break;

	case LTE_LC_EVT_NEIGHBOR_CELL_MEAS:
	case LTE_LC_EVT_MODEM_EVENT:
	default:
		break;
	}
}

/* ── Modem info callback for RSRP ────────────────────────────────────────*/

static void modem_info_rsrp_cb(char rsrp_value)
{
	/* nRF SDK encodes RSRP as: RSRP_dBm = rsrp_value - 141 */
	rsrp_cached = (int)rsrp_value - 141;
	LOG_DBG("RSRP: %d dBm", rsrp_cached);
}

/* ── Work handlers ───────────────────────────────────────────────────────*/

static void reconnect_handler(struct k_work *work)
{
	LOG_INF("LTE reconnect attempt");
	atomic_set(&connecting, 1);
	int ret = lte_lc_connect_async(lte_lc_event_handler);
	if (ret < 0) {
		LOG_ERR("lte_lc_connect_async failed: %d", ret);
		atomic_set(&connecting, 0);
	}
}

/* ── Public API ──────────────────────────────────────────────────────────*/

int lte_manager_init(void)
{
	int ret;

	/* Register event handler */
	lte_lc_register_handler(lte_lc_event_handler);

	/* Prefer LTE-M, fall back to NB-IoT */
	ret = lte_lc_system_mode_set(LTE_LC_SYSTEM_MODE_LTEM_NBIOT,
				     LTE_LC_SYSTEM_MODE_PREFER_LTEM);
	if (ret < 0) {
		LOG_ERR("System mode set failed: %d", ret);
		return ret;
	}

	/* Configure PSM and eDRX */
	configure_psm();
	configure_edrx();

	/* Modem info for RSRP polling */
	ret = modem_info_init();
	if (ret < 0) {
		LOG_WRN("modem_info_init failed: %d", ret);
	}
	modem_info_rsrp_register(modem_info_rsrp_cb);

	k_work_init_delayable(&reconnect_work, reconnect_handler);

	LOG_INF("LTE manager initialised");
	return 0;
}

int lte_manager_connect(void)
{
	if (atomic_get(&connected) || atomic_get(&connecting)) {
		return 0;
	}

	atomic_set(&connecting, 1);
	int ret = lte_lc_connect_async(lte_lc_event_handler);
	if (ret < 0) {
		LOG_ERR("LTE connect async failed: %d", ret);
		atomic_set(&connecting, 0);
		return ret;
	}

	LOG_INF("LTE connection attempt started");
	return 0;
}

int lte_manager_disconnect(void)
{
	int ret = lte_lc_offline();
	if (ret < 0) {
		LOG_ERR("LTE offline failed: %d", ret);
		return ret;
	}

	atomic_set(&connected, 0);
	atomic_set(&connecting, 0);
	LOG_INF("LTE disconnected");
	return 0;
}

bool lte_is_connected(void)
{
	return (bool)atomic_get(&connected);
}

int lte_get_signal_quality(int *rsrp, int *rsrq)
{
	if (!rsrp || !rsrq) {
		return -EINVAL;
	}

	*rsrp = rsrp_cached;

	/* RSRQ – read via AT command */
	char resp[64];
	int ret = nrf_modem_at_cmd(resp, sizeof(resp), "AT%%CESQ");
	if (ret == 0) {
		int _rsrq;
		/* Parse "+CESQ: <rxlev>,<ber>,<rscp>,<ecno>,<rsrq>,<rsrp>" */
		if (sscanf(resp, "%%CESQ: %*d,%*d,%*d,%*d,%d,%*d", &_rsrq) == 1) {
			rsrq_cached = _rsrq - 40; /* offset per TS 27.007 */
		}
	}
	*rsrq = rsrq_cached;
	return 0;
}

void lte_register_event_callback(void (*cb)(enum lte_event event))
{
	event_cb = cb;
}
