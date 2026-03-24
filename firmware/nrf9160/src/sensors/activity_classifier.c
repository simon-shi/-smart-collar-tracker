/*
 * Copyright (c) 2024 Smart Pet Collar Tracker
 * SPDX-License-Identifier: Apache-2.0
 *
 * Activity classifier – 2-second window (52 samples @ 26 Hz) decision tree.
 */
#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>
#include <math.h>
#include <string.h>
#include "activity_classifier.h"
#include "config.h"

LOG_MODULE_REGISTER(activity_classifier, LOG_LEVEL_DBG);

#define WINDOW_SAMPLES  52U   /* 26 Hz × 2 s */
#define ACCEL_AXES      3U

static uint32_t step_count;
static uint32_t calories_mcal;
static pet_activity_type_t current_activity = ACT_REST;
static K_MUTEX_DEFINE(cls_mutex);

/* Simple step detection state */
static bool step_above;
static int16_t step_threshold = 800; /* raw counts ~0.2g */

int activity_classifier_init(void)
{
	step_count     = 0;
	calories_mcal  = 0;
	current_activity = ACT_REST;
	LOG_INF("Activity classifier initialised");
	return 0;
}

pet_activity_type_t activity_classifier_process(const int16_t *accel_data,
						 uint16_t num_samples)
{
	if (!accel_data || num_samples == 0) {
		return ACT_REST;
	}

	uint16_t n = (num_samples > WINDOW_SAMPLES) ? WINDOW_SAMPLES : num_samples;

	/* Feature extraction over 3-axis data (interleaved x,y,z) */
	float sum_x = 0, sum_y = 0, sum_z = 0;
	float sum_sq_x = 0, sum_sq_y = 0, sum_sq_z = 0;
	int16_t min_z = INT16_MAX, max_z = INT16_MIN;

	for (uint16_t i = 0; i < n; i++) {
		float x = (float)accel_data[i * 3 + 0];
		float y = (float)accel_data[i * 3 + 1];
		float z = (float)accel_data[i * 3 + 2];
		sum_x += x; sum_sq_x += x * x;
		sum_y += y; sum_sq_y += y * y;
		sum_z += z; sum_sq_z += z * z;
		if (accel_data[i * 3 + 2] < min_z) min_z = accel_data[i * 3 + 2];
		if (accel_data[i * 3 + 2] > max_z) max_z = accel_data[i * 3 + 2];

		/* Step detection: zero-crossing on z-axis */
		if (!step_above && accel_data[i * 3 + 2] > step_threshold) {
			step_above = true;
		} else if (step_above && accel_data[i * 3 + 2] < -step_threshold) {
			step_above = false;
			k_mutex_lock(&cls_mutex, K_FOREVER);
			step_count++;
			k_mutex_unlock(&cls_mutex);
		}
	}

	float fn = (float)n;
	float var_x = (sum_sq_x / fn) - (sum_x / fn) * (sum_x / fn);
	float var_y = (sum_sq_y / fn) - (sum_y / fn) * (sum_y / fn);
	float var_z = (sum_sq_z / fn) - (sum_z / fn) * (sum_z / fn);
	float total_var = var_x + var_y + var_z;
	float p2p_z = (float)(max_z - min_z);

	/* Decision tree */
	pet_activity_type_t act;
	if (total_var < 5000.0f) {
		act = ACT_REST;
	} else if (total_var < 50000.0f) {
		act = (p2p_z > 3000.0f) ? ACT_WALK : ACT_REST;
	} else if (total_var < 200000.0f) {
		act = ACT_WALK;
	} else if (total_var < 600000.0f) {
		act = ACT_RUN;
	} else {
		/* High variance – could be play or swim; heuristic: swim has
		 * sustained z-variance without large peak-to-peak spikes. */
		act = (p2p_z < 8000.0f) ? ACT_SWIM : ACT_PLAY;
	}

	/* Calorie accumulation (crude MET estimate per 2 s window) */
	float met;
	switch (act) {
	case ACT_WALK:  met = 3.0f; break;
	case ACT_RUN:   met = 8.0f; break;
	case ACT_PLAY:  met = 5.0f; break;
	case ACT_SWIM:  met = 6.0f; break;
	default:        met = 1.0f; break;
	}
	/* kcal/min ≈ MET × weight_kg × 3.5 / 200; weight assumed 5 kg pet */
	float kcal_per_window = met * 5.0f * 3.5f / 200.0f * (2.0f / 60.0f);
	k_mutex_lock(&cls_mutex, K_FOREVER);
	calories_mcal += (uint32_t)(kcal_per_window * 1000.0f);
	current_activity = act;
	k_mutex_unlock(&cls_mutex);

	return act;
}

uint32_t activity_get_step_count(void)
{
	return step_count;
}

float activity_get_calories(float pet_weight_kg)
{
	(void)pet_weight_kg;
	return (float)calories_mcal / 1000.0f;
}

void activity_get_summary(struct activity_summary *summary)
{
	if (!summary) return;
	k_mutex_lock(&cls_mutex, K_FOREVER);
	summary->dominant_activity = current_activity;
	summary->steps             = step_count;
	summary->calories_mcal     = calories_mcal;
	k_mutex_unlock(&cls_mutex);
}
