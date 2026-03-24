/*
 * Copyright (c) 2024 Smart Pet Collar Tracker
 * SPDX-License-Identifier: Apache-2.0
 */
#ifndef FIRMWARE_NRF9160_LED_CONTROLLER_H_
#define FIRMWARE_NRF9160_LED_CONTROLLER_H_
#include <stdint.h>
#include <stdbool.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef enum {
	LED_OFF = 0, LED_SOLID, LED_BLINK, LED_BREATHE,
	LED_SOS, LED_RAINBOW, LED_NIGHT_SEARCH,
} led_pattern_t;
int led_controller_init(void);
void led_set_pattern(led_pattern_t pattern);
void led_set_color(uint8_t r, uint8_t g, uint8_t b);
void led_set_brightness(uint8_t brightness);
void led_night_search_mode(bool enable);
#ifdef __cplusplus
}
#endif
#endif /* FIRMWARE_NRF9160_LED_CONTROLLER_H_ */
