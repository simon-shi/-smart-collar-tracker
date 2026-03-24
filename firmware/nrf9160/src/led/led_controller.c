/*
 * Copyright (c) 2024 Smart Pet Collar Tracker
 * SPDX-License-Identifier: Apache-2.0
 *
 * LED controller – PWM-based RGB + white, pattern animations via work queue.
 */
#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>
#include <zephyr/drivers/pwm.h>
#include <zephyr/devicetree.h>
#include <math.h>
#include "led_controller.h"

LOG_MODULE_REGISTER(led_controller, LOG_LEVEL_DBG);

/* Device-tree PWM specs */
static const struct pwm_dt_spec led_r = PWM_DT_SPEC_GET(DT_NODELABEL(led_red));
static const struct pwm_dt_spec led_g = PWM_DT_SPEC_GET(DT_NODELABEL(led_green));
static const struct pwm_dt_spec led_b = PWM_DT_SPEC_GET(DT_NODELABEL(led_blue));
static const struct pwm_dt_spec led_w = PWM_DT_SPEC_GET(DT_NODELABEL(led_white));

#define PWM_PERIOD_NS  PWM_MSEC(20)
#define STEPS          256U

static uint8_t        cur_r, cur_g, cur_b;
static uint8_t        brightness = 255U;
static led_pattern_t  cur_pattern = LED_OFF;
static bool           night_mode;

static struct k_work_delayable anim_work;
static uint32_t anim_step;

/* ── PWM helpers ────────────────────────────────────────────────────────*/
static void set_rgb(uint8_t r, uint8_t g, uint8_t b)
{
	uint32_t pr = ((uint32_t)r * brightness / 255U) * PWM_PERIOD_NS / 255U;
	uint32_t pg = ((uint32_t)g * brightness / 255U) * PWM_PERIOD_NS / 255U;
	uint32_t pb = ((uint32_t)b * brightness / 255U) * PWM_PERIOD_NS / 255U;
	pwm_set_dt(&led_r, PWM_PERIOD_NS, pr);
	pwm_set_dt(&led_g, PWM_PERIOD_NS, pg);
	pwm_set_dt(&led_b, PWM_PERIOD_NS, pb);
}

static void set_white(uint8_t w)
{
	uint32_t pw = (uint32_t)w * PWM_PERIOD_NS / 255U;
	pwm_set_dt(&led_w, PWM_PERIOD_NS, pw);
}

/* ── Animation work handler ─────────────────────────────────────────────*/
static void anim_handler(struct k_work *work)
{
	switch (cur_pattern) {
	case LED_OFF:
		set_rgb(0, 0, 0);
		set_white(0);
		return;

	case LED_SOLID:
		set_rgb(cur_r, cur_g, cur_b);
		return;

	case LED_BLINK:
		if (anim_step & 1U) set_rgb(cur_r, cur_g, cur_b);
		else                 set_rgb(0, 0, 0);
		anim_step++;
		k_work_schedule(&anim_work, K_MSEC(500));
		break;

	case LED_BREATHE: {
		/* Sine wave 0..255 over 128 steps */
		float s = (sinf((float)anim_step * M_PI / 64.0f) + 1.0f) / 2.0f;
		uint8_t v = (uint8_t)(s * 255.0f);
		set_rgb((uint8_t)((uint32_t)cur_r * v / 255U),
			(uint8_t)((uint32_t)cur_g * v / 255U),
			(uint8_t)((uint32_t)cur_b * v / 255U));
		anim_step = (anim_step + 1) % 128U;
		k_work_schedule(&anim_work, K_MSEC(20));
		break;
	}

	case LED_SOS: {
		/* S=··· O=−−− S=··· */
		static const uint8_t pattern[] = {
			1,0,1,0,1,0, 0,0, /* S */
			3,0,3,0,3,0, 0,0, /* O */
			1,0,1,0,1,0, 0,0, /* S */
			0,0,0,0,0,0, 0,0  /* pause */
		};
		uint8_t dur = pattern[anim_step % ARRAY_SIZE(pattern)];
		if (dur > 0) set_rgb(255, 0, 0);
		else         set_rgb(0, 0, 0);
		anim_step++;
		k_work_schedule(&anim_work, K_MSEC(200 * (dur > 0 ? dur : 1)));
		break;
	}

	case LED_RAINBOW: {
		/* Hue rotation */
		uint16_t h = (anim_step % 360U);
		float hr = (float)h / 60.0f;
		float x  = 1.0f - fabsf(fmodf(hr, 2.0f) - 1.0f);
		float r = 0, g = 0, b = 0;
		if      (hr < 1) { r = 1; g = x; }
		else if (hr < 2) { r = x; g = 1; }
		else if (hr < 3) { g = 1; b = x; }
		else if (hr < 4) { g = x; b = 1; }
		else if (hr < 5) { r = x; b = 1; }
		else             { r = 1; b = x; }
		set_rgb((uint8_t)(r*255), (uint8_t)(g*255), (uint8_t)(b*255));
		anim_step++;
		k_work_schedule(&anim_work, K_MSEC(30));
		break;
	}

	case LED_NIGHT_SEARCH:
		/* White LED 2 Hz flash */
		if (anim_step & 1U) set_white(255);
		else                 set_white(0);
		anim_step++;
		k_work_schedule(&anim_work, K_MSEC(250));
		break;

	default:
		break;
	}
}

/* ── Public API ─────────────────────────────────────────────────────────*/
int led_controller_init(void)
{
	if (!pwm_is_ready_dt(&led_r) || !pwm_is_ready_dt(&led_g) ||
	    !pwm_is_ready_dt(&led_b) || !pwm_is_ready_dt(&led_w)) {
		LOG_ERR("One or more PWM devices not ready");
		return -ENODEV;
	}
	k_work_init_delayable(&anim_work, anim_handler);
	set_rgb(0, 0, 0);
	set_white(0);
	cur_r = 0; cur_g = 100; cur_b = 200; /* default: blue-green */
	LOG_INF("LED controller initialised");
	return 0;
}

void led_set_pattern(led_pattern_t pattern)
{
	k_work_cancel_delayable(&anim_work);
	anim_step   = 0;
	cur_pattern = pattern;
	k_work_schedule(&anim_work, K_NO_WAIT);
}

void led_set_color(uint8_t r, uint8_t g, uint8_t b)
{
	cur_r = r; cur_g = g; cur_b = b;
}

void led_set_brightness(uint8_t b)
{
	brightness = b;
}

void led_night_search_mode(bool enable)
{
	night_mode = enable;
	led_set_pattern(enable ? LED_NIGHT_SEARCH : LED_OFF);
}
