/*
 * Copyright (c) 2024 Smart Pet Collar Tracker
 * SPDX-License-Identifier: Apache-2.0
 *
 * Charge Manager – implementation.
 *
 * GPIOs (from device tree aliases):
 *   chg-detect : P1.02 active-low – magnetic connector present
 *   chg-stat   : P1.03 active-low – nPM1100 CHG_STAT (low = charging)
 */

#include "charge_manager.h"

#include <zephyr/kernel.h>
#include <zephyr/device.h>
#include <zephyr/drivers/gpio.h>
#include <zephyr/logging/log.h>

LOG_MODULE_REGISTER(charge_mgr, LOG_LEVEL_INF);

/* -----------------------------------------------------------------------
 * GPIO descriptors from DT aliases
 * -------------------------------------------------------------------- */
static const struct gpio_dt_spec chg_det  =
	GPIO_DT_SPEC_GET(DT_ALIAS(chg_detect), gpios);
static const struct gpio_dt_spec chg_stat =
	GPIO_DT_SPEC_GET(DT_ALIAS(chg_stat), gpios);

/* -----------------------------------------------------------------------
 * Module state
 * -------------------------------------------------------------------- */
static struct gpio_callback det_cb_data;
static struct gpio_callback stat_cb_data;

static volatile bool connector_present;
static volatile bool currently_charging;

static void (*user_cb)(bool connected, bool charging);

/* -----------------------------------------------------------------------
 * Work item – fire the user callback from the system work queue
 * -------------------------------------------------------------------- */
static struct k_work charge_work;

static void charge_work_handler(struct k_work *work)
{
	bool conn  = connector_present;
	bool charg = currently_charging;

	LOG_INF("Charge state: connector=%d charging=%d", conn, charg);

	if (user_cb) {
		user_cb(conn, charg);
	}
}

/* -----------------------------------------------------------------------
 * GPIO interrupt handlers
 * -------------------------------------------------------------------- */
static void det_gpio_cb(const struct device *dev,
			struct gpio_callback *cb,
			uint32_t pins)
{
	/* Active-low: pin low → connector present */
	connector_present = (gpio_pin_get_dt(&chg_det) == 0);
	k_work_submit(&charge_work);
}

static void stat_gpio_cb(const struct device *dev,
			 struct gpio_callback *cb,
			 uint32_t pins)
{
	/* Active-low: pin low → charging */
	currently_charging = (gpio_pin_get_dt(&chg_stat) == 0);
	k_work_submit(&charge_work);
}

/* -----------------------------------------------------------------------
 * Public API
 * -------------------------------------------------------------------- */

int charge_manager_init(void)
{
	int err;

	k_work_init(&charge_work, charge_work_handler);

	/* Connector detect */
	if (!gpio_is_ready_dt(&chg_det)) {
		LOG_ERR("chg_detect GPIO not ready");
		return -ENODEV;
	}
	err = gpio_pin_configure_dt(&chg_det, GPIO_INPUT);
	if (err) {
		LOG_ERR("chg_detect configure failed: %d", err);
		return err;
	}
	err = gpio_pin_interrupt_configure_dt(&chg_det,
					      GPIO_INT_EDGE_BOTH);
	if (err) {
		LOG_ERR("chg_detect interrupt configure failed: %d", err);
		return err;
	}
	gpio_init_callback(&det_cb_data, det_gpio_cb,
			   BIT(chg_det.pin));
	gpio_add_callback(chg_det.port, &det_cb_data);

	/* Charge status */
	if (!gpio_is_ready_dt(&chg_stat)) {
		LOG_ERR("chg_stat GPIO not ready");
		return -ENODEV;
	}
	err = gpio_pin_configure_dt(&chg_stat, GPIO_INPUT);
	if (err) {
		LOG_ERR("chg_stat configure failed: %d", err);
		return err;
	}
	err = gpio_pin_interrupt_configure_dt(&chg_stat,
					      GPIO_INT_EDGE_BOTH);
	if (err) {
		LOG_ERR("chg_stat interrupt configure failed: %d", err);
		return err;
	}
	gpio_init_callback(&stat_cb_data, stat_gpio_cb,
			   BIT(chg_stat.pin));
	gpio_add_callback(chg_stat.port, &stat_cb_data);

	/* Read initial state */
	connector_present  = (gpio_pin_get_dt(&chg_det)  == 0);
	currently_charging = (gpio_pin_get_dt(&chg_stat) == 0);

	LOG_INF("Charge manager initialised: connector=%d charging=%d",
		connector_present, currently_charging);
	return 0;
}

bool charge_is_connected(void)
{
	return connector_present;
}

bool charge_is_charging(void)
{
	return currently_charging;
}

void charge_register_callback(void (*cb)(bool connected, bool charging))
{
	user_cb = cb;
}
