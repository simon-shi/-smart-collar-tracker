/*
 * Copyright (c) 2024 Smart Pet Collar Tracker
 * SPDX-License-Identifier: Apache-2.0
 *
 * LSM6DSO 6-axis IMU driver over I2C.
 * Implements accelerometer / gyroscope configuration, data reads,
 * wake-on-motion (INT1), and activity interrupt (INT2).
 */

#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>
#include <zephyr/drivers/i2c.h>
#include <zephyr/drivers/gpio.h>
#include <zephyr/devicetree.h>
#include <string.h>

#include "lsm6dso_driver.h"
#include "config.h"

LOG_MODULE_REGISTER(lsm6dso, LOG_LEVEL_INF);

/* ── Device-tree node ───────────────────────────────────────────────────*/
#define LSM6DSO_NODE  DT_NODELABEL(lsm6dso)
#define LSM6DSO_BUS   DT_BUS(LSM6DSO_NODE)

static const struct device *i2c_dev;
static const uint8_t i2c_addr = LSM6DSO_I2C_ADDR;

/* ── INT1 GPIO for wake-on-motion ───────────────────────────────────────*/
static const struct gpio_dt_spec int1_gpio =
	GPIO_DT_SPEC_GET_BY_IDX(LSM6DSO_NODE, irq_gpios, 0);
static const struct gpio_dt_spec int2_gpio =
	GPIO_DT_SPEC_GET_BY_IDX(LSM6DSO_NODE, irq_gpios, 1);

static struct gpio_callback int1_cb_data;
static void (*wakeup_cb)(void);

/* ── Current full-scale for scaling ────────────────────────────────────*/
static uint8_t accel_fs_reg = LSM6DSO_FS_4G;

/* ── Register helpers ───────────────────────────────────────────────────*/

static int reg_write(uint8_t reg, uint8_t val)
{
	uint8_t buf[2] = { reg, val };
	return i2c_write(i2c_dev, buf, sizeof(buf), i2c_addr);
}

static int reg_read(uint8_t reg, uint8_t *val)
{
	return i2c_write_read(i2c_dev, i2c_addr, &reg, 1, val, 1);
}

static int reg_update(uint8_t reg, uint8_t mask, uint8_t bits)
{
	uint8_t val;
	int ret = reg_read(reg, &val);
	if (ret < 0) {
		return ret;
	}
	val = (val & ~mask) | (bits & mask);
	return reg_write(reg, val);
}

/* ── INT1 GPIO ISR ──────────────────────────────────────────────────────*/
static void int1_isr(const struct device *dev,
		     struct gpio_callback *cb, uint32_t pins)
{
	if (wakeup_cb) {
		wakeup_cb();
	}
}

/* ── Public API ─────────────────────────────────────────────────────────*/

int lsm6dso_init(void)
{
	int ret;
	uint8_t who_am_i;

	i2c_dev = DEVICE_DT_GET(LSM6DSO_BUS);
	if (!device_is_ready(i2c_dev)) {
		LOG_ERR("I2C bus not ready");
		return -ENODEV;
	}

	/* Verify WHO_AM_I */
	ret = reg_read(LSM6DSO_REG_WHO_AM_I, &who_am_i);
	if (ret < 0) {
		LOG_ERR("WHO_AM_I read failed: %d", ret);
		return ret;
	}
	if (who_am_i != LSM6DSO_WHO_AM_I_VAL) {
		LOG_ERR("WHO_AM_I mismatch: got 0x%02X, expected 0x%02X",
			who_am_i, LSM6DSO_WHO_AM_I_VAL);
		return -ENODEV;
	}

	/* Software reset */
	ret = reg_write(LSM6DSO_REG_CTRL3_C, 0x01U);
	if (ret < 0) {
		LOG_ERR("SW reset failed: %d", ret);
		return ret;
	}
	k_busy_wait(5000); /* 5 ms reset time */

	/* BDU enabled, auto-increment address */
	ret = reg_write(LSM6DSO_REG_CTRL3_C, 0x44U);
	if (ret < 0) {
		return ret;
	}

	/* Configure GPIO pins for interrupts */
	if (gpio_is_ready_dt(&int1_gpio)) {
		gpio_pin_configure_dt(&int1_gpio, GPIO_INPUT);
		gpio_pin_interrupt_configure_dt(&int1_gpio,
						GPIO_INT_EDGE_RISING);
		gpio_init_callback(&int1_cb_data, int1_isr,
				   BIT(int1_gpio.pin));
		gpio_add_callback(int1_gpio.port, &int1_cb_data);
	}
	if (gpio_is_ready_dt(&int2_gpio)) {
		gpio_pin_configure_dt(&int2_gpio, GPIO_INPUT);
	}

	LOG_INF("LSM6DSO initialised (WHO_AM_I=0x%02X)", who_am_i);
	return 0;
}

int lsm6dso_configure_accel(uint8_t odr, uint8_t range)
{
	/* CTRL1_XL: ODR_XL[7:4] | FS_XL[3:2] | LPF2_XL_EN[1] | 0 */
	uint8_t ctrl = (uint8_t)((odr << 4) | (range << 2));
	int ret = reg_write(LSM6DSO_REG_CTRL1_XL, ctrl);
	if (ret < 0) {
		LOG_ERR("Accel configure failed: %d", ret);
		return ret;
	}
	accel_fs_reg = range;
	LOG_DBG("Accel ODR=0x%X FS=0x%X", odr, range);
	return 0;
}

int lsm6dso_configure_gyro(uint8_t odr, uint8_t range)
{
	/* CTRL2_G: ODR_G[7:4] | FS_G[3:1] | FS_125[0] */
	uint8_t ctrl = (uint8_t)((odr << 4) | (range << 1));
	int ret = reg_write(LSM6DSO_REG_CTRL2_G, ctrl);
	if (ret < 0) {
		LOG_ERR("Gyro configure failed: %d", ret);
	}
	return ret;
}

int lsm6dso_read_accel(int16_t *x, int16_t *y, int16_t *z)
{
	if (!x || !y || !z) {
		return -EINVAL;
	}

	uint8_t buf[6];
	uint8_t reg = LSM6DSO_REG_OUTX_L_A;
	int ret = i2c_write_read(i2c_dev, i2c_addr, &reg, 1, buf, 6);
	if (ret < 0) {
		LOG_ERR("Accel read failed: %d", ret);
		return ret;
	}

	*x = (int16_t)((buf[1] << 8) | buf[0]);
	*y = (int16_t)((buf[3] << 8) | buf[2]);
	*z = (int16_t)((buf[5] << 8) | buf[4]);
	return 0;
}

int lsm6dso_read_gyro(int16_t *x, int16_t *y, int16_t *z)
{
	if (!x || !y || !z) {
		return -EINVAL;
	}

	uint8_t buf[6];
	uint8_t reg = LSM6DSO_REG_OUTX_L_G;
	int ret = i2c_write_read(i2c_dev, i2c_addr, &reg, 1, buf, 6);
	if (ret < 0) {
		LOG_ERR("Gyro read failed: %d", ret);
		return ret;
	}

	*x = (int16_t)((buf[1] << 8) | buf[0]);
	*y = (int16_t)((buf[3] << 8) | buf[2]);
	*z = (int16_t)((buf[5] << 8) | buf[4]);
	return 0;
}

int lsm6dso_read_temperature(float *temp_c)
{
	if (!temp_c) {
		return -EINVAL;
	}

	uint8_t buf[2];
	uint8_t reg = LSM6DSO_REG_OUT_TEMP_L;
	int ret = i2c_write_read(i2c_dev, i2c_addr, &reg, 1, buf, 2);
	if (ret < 0) {
		LOG_ERR("Temperature read failed: %d", ret);
		return ret;
	}

	int16_t raw = (int16_t)((buf[1] << 8) | buf[0]);
	/* 1 LSB = 1/256 °C, offset = 25 °C */
	*temp_c = 25.0f + (float)raw / 256.0f;
	return 0;
}

int lsm6dso_configure_wakeup(uint8_t threshold_mg)
{
	int ret;

	/* Enable slope filter, set wake-up threshold (6-bit, 1 LSB = FS/64) */
	/* For 4G FS: 1 LSB ≈ 62.5 mg; threshold_mg / 62 gives register value */
	uint8_t thr = (uint8_t)(threshold_mg / 62U);
	if (thr == 0) {
		thr = 1;
	}
	if (thr > 63) {
		thr = 63;
	}

	/* WAKE_UP_THS: WK_THS[5:0], SINGLE_DOUBLE_TAP[7], USR_OFF_ON_WU[6] */
	ret = reg_write(LSM6DSO_REG_WAKE_UP_THS, thr & 0x3FU);
	if (ret < 0) {
		LOG_ERR("Wake-up threshold write failed: %d", ret);
		return ret;
	}

	/* WAKE_UP_DUR: WAKE_DUR[5:4]=01 (2 samples), SLEEP_DUR[3:0] */
	ret = reg_write(LSM6DSO_REG_WAKE_UP_DUR, 0x10U);
	if (ret < 0) {
		return ret;
	}

	/* Enable SLOPE_FLT and LIR in TAP_CFG0 */
	ret = reg_write(LSM6DSO_REG_TAP_CFG0, 0x10U); /* SLOPE_FLT_EN */
	if (ret < 0) {
		return ret;
	}

	/* Route wake-up interrupt to INT1 via MD1_CFG */
	ret = reg_update(LSM6DSO_REG_MD1_CFG, 0x20U, 0x20U); /* INT1_WU */
	if (ret < 0) {
		return ret;
	}

	LOG_INF("Wake-on-motion configured: threshold=%u mg (reg=%u)",
		(unsigned)threshold_mg, (unsigned)thr);
	return 0;
}

int lsm6dso_configure_activity_int(void)
{
	int ret;

	/* Enable inactivity detection: SLEEP_EN in CTRL4_C */
	ret = reg_update(LSM6DSO_REG_CTRL4_C, 0x40U, 0x40U);
	if (ret < 0) {
		LOG_ERR("Sleep enable failed: %d", ret);
		return ret;
	}

	/* Route sleep-change interrupt to INT2 via MD2_CFG */
	ret = reg_update(LSM6DSO_REG_MD2_CFG, 0x80U, 0x80U); /* INT2_SLEEP_CHANGE */
	if (ret < 0) {
		return ret;
	}

	LOG_INF("Activity/inactivity interrupt configured on INT2");
	return 0;
}

void lsm6dso_register_wakeup_callback(void (*cb)(void))
{
	wakeup_cb = cb;
}
