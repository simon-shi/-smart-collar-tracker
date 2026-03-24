/*
 * Copyright (c) 2024 Smart Pet Collar Tracker
 * SPDX-License-Identifier: Apache-2.0
 */
#ifndef FIRMWARE_NRF9160_GEOFENCE_ENGINE_H_
#define FIRMWARE_NRF9160_GEOFENCE_ENGINE_H_
#include <stdint.h>
#include <stdbool.h>
#include "pet_data.h"
#ifdef __cplusplus
extern "C" {
#endif
int geofence_engine_init(void);
int geofence_add_circle(uint8_t id, double lat, double lon, uint32_t radius_m);
struct geofence_vertex { double lat; double lon; };
int geofence_add_polygon(uint8_t id, const struct geofence_vertex *vertices, uint8_t num_vertices);
int geofence_remove(uint8_t id);
void geofence_check_position(double lat, double lon);
void geofence_register_alert_callback(void (*cb)(const geofence_alert_t *alert));
#ifdef __cplusplus
}
#endif
#endif /* FIRMWARE_NRF9160_GEOFENCE_ENGINE_H_ */
