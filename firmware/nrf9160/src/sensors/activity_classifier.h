/*
 * Copyright (c) 2024 Smart Pet Collar Tracker
 * SPDX-License-Identifier: Apache-2.0
 */
#ifndef FIRMWARE_NRF9160_ACTIVITY_CLASSIFIER_H_
#define FIRMWARE_NRF9160_ACTIVITY_CLASSIFIER_H_
#include <stdint.h>
#include "pet_data.h"
#include "cloud/codec.h"
#ifdef __cplusplus
extern "C" {
#endif
int activity_classifier_init(void);
pet_activity_type_t activity_classifier_process(const int16_t *accel_data, uint16_t num_samples);
uint32_t activity_get_step_count(void);
float activity_get_calories(float pet_weight_kg);
void activity_get_summary(struct activity_summary *summary);
#ifdef __cplusplus
}
#endif
#endif /* FIRMWARE_NRF9160_ACTIVITY_CLASSIFIER_H_ */
