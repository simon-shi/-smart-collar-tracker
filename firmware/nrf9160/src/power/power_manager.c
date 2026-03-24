/*
 * Copyright (c) 2024 Smart Pet Collar Tracker
 * SPDX-License-Identifier: Apache-2.0
 *
 * Power manager – state machine + ADC battery monitoring.
 */
#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>
#include <zephyr/drivers/adc.h>
#include <zephyr/drivers/gpio.h>
#include <zephyr/devicetree.h>
#include <math.h>
#include "power_manager.h"
#include "config.h"
#include "gps/gps_controller.h"

LOG_MODULE_REGISTER(power_manager, LOG_LEVEL_INF);

#define ADC_NODE      DT_NODELABEL(adc)
#define ADC_CHANNEL   0
#define ADC_RESOLUTION 12
#define ADC_VREF_MV   600   /* nRF9160 internal 0.6 V reference */
#define ADC_GAIN_INV  6     /* 1/6 gain → effective ref = 3.6 V */
#define VDIV_FACTOR   2     /* voltage divider: R1=R2 → ×2 */

static const struct device *adc_dev;
static int16_t adc_sample_buf;
static struct adc_sequence adc_seq = {
	.buffer      = &adc_sample_buf,
	.buffer_size = sizeof(adc_sample_buf),
};
static struct adc_channel_cfg adc_ch_cfg = {
	.gain             = ADC_GAIN_1_6,
	.reference        = ADC_REF_INTERNAL,
	.acquisition_time = ADC_ACQ_TIME_DEFAULT,
	.channel_id       = ADC_CHANNEL,
	.input_positive   = NRF_SAADC_AIN1,
};

static power_mode_t current_mode = PWR_ACTIVE;
static uint8_t  bat_pct = 100;
static uint16_t bat_mv  = BATTERY_FULL_MV;
static void (*batt_cb)(uint8_t);

static K_MUTEX_DEFINE(pwr_mutex);
static struct k_work_delayable bat_work;

/* ── Battery measurement ────────────────────────────────────────────────*/
static uint16_t measure_battery_mv(void)
{
	if (!adc_dev) return BATTERY_FULL_MV;
	adc_seq.channels    = BIT(ADC_CHANNEL);
	adc_seq.resolution  = ADC_RESOLUTION;
	adc_seq.oversampling = 3; /* 8× */

	if (adc_read(adc_dev, &adc_seq) < 0) return bat_mv;

	int32_t mv = adc_sample_buf;
	adc_raw_to_millivolts(ADC_VREF_MV * ADC_GAIN_INV, ADC_GAIN_1_6,
			      ADC_RESOLUTION, &mv);
	return (uint16_t)(mv * VDIV_FACTOR);
}

static uint8_t mv_to_percent(uint16_t mv)
{
	if (mv >= BATTERY_FULL_MV)  return 100U;
	if (mv <= BATTERY_EMPTY_MV) return 0U;
	return (uint8_t)(((uint32_t)(mv - BATTERY_EMPTY_MV) * 100U) /
			 (BATTERY_FULL_MV - BATTERY_EMPTY_MV));
}

static void bat_work_handler(struct k_work *work)
{
	uint16_t mv  = measure_battery_mv();
	uint8_t  pct = mv_to_percent(mv);

	k_mutex_lock(&pwr_mutex, K_FOREVER);
	bat_mv  = mv;
	bat_pct = pct;
	k_mutex_unlock(&pwr_mutex);

	LOG_DBG("Battery: %u mV, %u%%", mv, pct);

	if (batt_cb && (pct <= BATTERY_LOW_THRESHOLD_PCT)) {
		batt_cb(pct);
	}

	k_work_schedule(&bat_work, K_SECONDS(60));
}

/* ── Mode application ───────────────────────────────────────────────────*/
static void apply_mode(power_mode_t mode)
{
	uint32_t gps_interval;
	switch (mode) {
	case PWR_DEEP_SLEEP: gps_interval = GPS_FIX_INTERVAL_DEEP_SLEEP_S; break;
	case PWR_LOW_POWER:  gps_interval = GPS_FIX_INTERVAL_LOW_POWER_S;  break;
	case PWR_TRACKING:   gps_interval = GPS_FIX_INTERVAL_TRACKING_S;   break;
	default:             gps_interval = GPS_FIX_INTERVAL_ACTIVE_S;     break;
	}
	gps_set_fix_interval(gps_interval);
	LOG_INF("Power mode -> %d (GPS interval=%u s)", mode, gps_interval);
}

/* ── Public API ─────────────────────────────────────────────────────────*/
int power_manager_init(void)
{
	adc_dev = DEVICE_DT_GET(ADC_NODE);
	if (device_is_ready(adc_dev)) {
		adc_channel_setup(adc_dev, &adc_ch_cfg);
	} else {
		LOG_WRN("ADC device not ready");
		adc_dev = NULL;
	}
	k_work_init_delayable(&bat_work, bat_work_handler);
	k_work_schedule(&bat_work, K_SECONDS(5));
	apply_mode(current_mode);
	LOG_INF("Power manager initialised");
	return 0;
}

void power_set_mode(power_mode_t mode)
{
	k_mutex_lock(&pwr_mutex, K_FOREVER);
	current_mode = mode;
	k_mutex_unlock(&pwr_mutex);
	apply_mode(mode);
}

power_mode_t power_get_mode(void)
{
	return current_mode;
}

uint8_t power_get_battery_percent(void)
{
	return bat_pct;
}

uint16_t power_get_battery_mv(void)
{
	return bat_mv;
}

void power_register_battery_callback(void (*cb)(uint8_t percent))
{
	batt_cb = cb;
}
