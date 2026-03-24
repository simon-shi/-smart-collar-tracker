/*
 * Copyright (c) 2024 Smart Pet Collar Tracker
 * SPDX-License-Identifier: Apache-2.0
 */

#ifndef FIRMWARE_NRF9160_LSM6DSO_DRIVER_H_
#define FIRMWARE_NRF9160_LSM6DSO_DRIVER_H_

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ── LSM6DSO I2C address ─────────────────────────────────────────────── */
#define LSM6DSO_I2C_ADDR        0x6AU

/* ── Register map ───────────────────────────────────────────────────── */
#define LSM6DSO_REG_FUNC_CFG_ACCESS   0x01U
#define LSM6DSO_REG_PIN_CTRL          0x02U
#define LSM6DSO_REG_FIFO_CTRL1        0x07U
#define LSM6DSO_REG_FIFO_CTRL2        0x08U
#define LSM6DSO_REG_FIFO_CTRL3        0x09U
#define LSM6DSO_REG_FIFO_CTRL4        0x0AU
#define LSM6DSO_REG_COUNTER_BDR_REG1  0x0BU
#define LSM6DSO_REG_COUNTER_BDR_REG2  0x0CU
#define LSM6DSO_REG_INT1_CTRL         0x0DU
#define LSM6DSO_REG_INT2_CTRL         0x0EU
#define LSM6DSO_REG_WHO_AM_I          0x0FU
#define LSM6DSO_REG_CTRL1_XL          0x10U
#define LSM6DSO_REG_CTRL2_G           0x11U
#define LSM6DSO_REG_CTRL3_C           0x12U
#define LSM6DSO_REG_CTRL4_C           0x13U
#define LSM6DSO_REG_CTRL5_C           0x14U
#define LSM6DSO_REG_CTRL6_C           0x15U
#define LSM6DSO_REG_CTRL7_G           0x16U
#define LSM6DSO_REG_CTRL8_XL          0x17U
#define LSM6DSO_REG_CTRL9_XL          0x18U
#define LSM6DSO_REG_CTRL10_C          0x19U
#define LSM6DSO_REG_ALL_INT_SRC       0x1AU
#define LSM6DSO_REG_WAKE_UP_SRC       0x1BU
#define LSM6DSO_REG_TAP_SRC           0x1CU
#define LSM6DSO_REG_D6D_SRC           0x1DU
#define LSM6DSO_REG_STATUS_REG        0x1EU
#define LSM6DSO_REG_OUT_TEMP_L        0x20U
#define LSM6DSO_REG_OUT_TEMP_H        0x21U
#define LSM6DSO_REG_OUTX_L_G          0x22U
#define LSM6DSO_REG_OUTX_H_G          0x23U
#define LSM6DSO_REG_OUTY_L_G          0x24U
#define LSM6DSO_REG_OUTY_H_G          0x25U
#define LSM6DSO_REG_OUTZ_L_G          0x26U
#define LSM6DSO_REG_OUTZ_H_G          0x27U
#define LSM6DSO_REG_OUTX_L_A          0x28U
#define LSM6DSO_REG_OUTX_H_A          0x29U
#define LSM6DSO_REG_OUTY_L_A          0x2AU
#define LSM6DSO_REG_OUTY_H_A          0x2BU
#define LSM6DSO_REG_OUTZ_L_A          0x2CU
#define LSM6DSO_REG_OUTZ_H_A          0x2DU
#define LSM6DSO_REG_TAP_CFG0          0x56U
#define LSM6DSO_REG_TAP_CFG1          0x57U
#define LSM6DSO_REG_TAP_CFG2          0x58U
#define LSM6DSO_REG_TAP_THS_6D        0x59U
#define LSM6DSO_REG_WAKE_UP_THS       0x5BU
#define LSM6DSO_REG_WAKE_UP_DUR       0x5CU
#define LSM6DSO_REG_MD1_CFG           0x5EU
#define LSM6DSO_REG_MD2_CFG           0x5FU

#define LSM6DSO_WHO_AM_I_VAL          0x6CU

/**
 * @brief Initialise the LSM6DSO driver.
 *
 * Verifies the WHO_AM_I register, resets the device, and applies default
 * configuration.
 *
 * @return 0 on success, negative errno on failure.
 */
int lsm6dso_init(void);

/**
 * @brief Configure the accelerometer ODR and full-scale range.
 *
 * @param odr    ODR register value (LSM6DSO_ODR_* from config.h).
 * @param range  Full-scale register value (LSM6DSO_FS_* from config.h).
 *
 * @return 0 on success, negative errno on failure.
 */
int lsm6dso_configure_accel(uint8_t odr, uint8_t range);

/**
 * @brief Configure the gyroscope ODR and full-scale range.
 *
 * @param odr    ODR register value.
 * @param range  Full-scale register value (dps).
 *
 * @return 0 on success, negative errno on failure.
 */
int lsm6dso_configure_gyro(uint8_t odr, uint8_t range);

/**
 * @brief Read raw accelerometer data.
 *
 * @param[out] x  X-axis raw ADC count.
 * @param[out] y  Y-axis raw ADC count.
 * @param[out] z  Z-axis raw ADC count.
 *
 * @return 0 on success, negative errno on failure.
 */
int lsm6dso_read_accel(int16_t *x, int16_t *y, int16_t *z);

/**
 * @brief Read raw gyroscope data.
 *
 * @param[out] x  X-axis raw ADC count.
 * @param[out] y  Y-axis raw ADC count.
 * @param[out] z  Z-axis raw ADC count.
 *
 * @return 0 on success, negative errno on failure.
 */
int lsm6dso_read_gyro(int16_t *x, int16_t *y, int16_t *z);

/**
 * @brief Read the temperature sensor.
 *
 * @param[out] temp_c  Temperature in degrees Celsius.
 *
 * @return 0 on success, negative errno on failure.
 */
int lsm6dso_read_temperature(float *temp_c);

/**
 * @brief Configure wake-on-motion interrupt on INT1.
 *
 * @param threshold_mg  Motion threshold in milli-g.
 *
 * @return 0 on success, negative errno on failure.
 */
int lsm6dso_configure_wakeup(uint8_t threshold_mg);

/**
 * @brief Configure the activity/inactivity interrupt on INT2.
 *
 * @return 0 on success, negative errno on failure.
 */
int lsm6dso_configure_activity_int(void);

/**
 * @brief Register a callback for wake-on-motion events (INT1).
 *
 * @param cb  Callback to invoke when motion is detected. Called from ISR.
 */
void lsm6dso_register_wakeup_callback(void (*cb)(void));

#ifdef __cplusplus
}
#endif

#endif /* FIRMWARE_NRF9160_LSM6DSO_DRIVER_H_ */
