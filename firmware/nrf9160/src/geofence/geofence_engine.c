/*
 * Copyright (c) 2024 Smart Pet Collar Tracker
 * SPDX-License-Identifier: Apache-2.0
 *
 * Geofence engine – circular and polygon zones with NVS persistence,
 * haversine distance, ray-casting, and 30 s dwell-time hysteresis.
 */
#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>
#include <zephyr/fs/nvs.h>
#include <zephyr/drivers/flash.h>
#include <zephyr/storage/flash_map.h>
#include <math.h>
#include <string.h>
#include "geofence_engine.h"
#include "config.h"

LOG_MODULE_REGISTER(geofence_engine, LOG_LEVEL_INF);

#define MAX_POLYGON_VERTICES  20U
#define DWELL_TIME_S          30U
#define EARTH_RADIUS_M        6371000.0

#define GEO_NVS_ID_BASE       100U

typedef enum { FENCE_NONE = 0, FENCE_CIRCLE, FENCE_POLYGON } fence_type_t;

typedef struct {
	uint8_t      id;
	fence_type_t type;
	bool         active;
	bool         pet_inside;
	uint32_t     entry_time_s;
	/* Circle */
	double  lat;
	double  lon;
	double  radius_m;
	/* Polygon */
	struct geofence_vertex verts[MAX_POLYGON_VERTICES];
	uint8_t num_verts;
} fence_t;

static fence_t fences[MAX_GEOFENCES];
static void (*alert_cb)(const geofence_alert_t *);
static K_MUTEX_DEFINE(geo_mutex);

static struct nvs_fs nvs;
static bool nvs_ready;

/* ── NVS ────────────────────────────────────────────────────────────────*/
static void nvs_init(void)
{
	const struct flash_area *fa;
	if (flash_area_open(FIXED_PARTITION_ID(storage_partition), &fa) < 0) {
		LOG_WRN("NVS flash area open failed");
		return;
	}
	nvs.flash_device = fa->fa_dev;
	nvs.offset       = fa->fa_off;
	nvs.sector_size  = FLASH_SECTOR_SIZE;
	nvs.sector_count = 2;
	if (nvs_mount(&nvs) < 0) {
		LOG_WRN("NVS mount failed");
		return;
	}
	nvs_ready = true;
	flash_area_close(fa);
}

static void save_fence(const fence_t *f)
{
	if (!nvs_ready) return;
	nvs_write(&nvs, GEO_NVS_ID_BASE + f->id, f, sizeof(*f));
}

static void load_fences(void)
{
	if (!nvs_ready) return;
	for (uint8_t i = 0; i < MAX_GEOFENCES; i++) {
		fence_t tmp;
		if (nvs_read(&nvs, GEO_NVS_ID_BASE + i, &tmp, sizeof(tmp)) == sizeof(tmp)) {
			if (tmp.active) {
				fences[i] = tmp;
				LOG_INF("Loaded geofence id=%u type=%d", tmp.id, tmp.type);
			}
		}
	}
}

/* ── Haversine ──────────────────────────────────────────────────────────*/
static double haversine_m(double lat1, double lon1, double lat2, double lon2)
{
	double dlat = (lat2 - lat1) * M_PI / 180.0;
	double dlon = (lon2 - lon1) * M_PI / 180.0;
	double a = sin(dlat/2)*sin(dlat/2) +
		   cos(lat1*M_PI/180.0)*cos(lat2*M_PI/180.0)*
		   sin(dlon/2)*sin(dlon/2);
	return EARTH_RADIUS_M * 2.0 * atan2(sqrt(a), sqrt(1.0 - a));
}

/* ── Ray casting ────────────────────────────────────────────────────────*/
static bool point_in_polygon(double lat, double lon,
			      const struct geofence_vertex *v, uint8_t n)
{
	bool inside = false;
	for (uint8_t i = 0, j = n - 1; i < n; j = i++) {
		double xi = v[i].lat, yi = v[i].lon;
		double xj = v[j].lat, yj = v[j].lon;
		if (((yi > lon) != (yj > lon)) &&
		    (lat < (xj - xi) * (lon - yi) / (yj - yi) + xi)) {
			inside = !inside;
		}
	}
	return inside;
}

/* ── Alert dispatch ─────────────────────────────────────────────────────*/
static void dispatch_alert(fence_t *f, breach_type_t btype,
			   double lat, double lon)
{
	geofence_alert_t alert = {
		.fence_id    = f->id,
		.breach_type = btype,
		.timestamp_s = (uint32_t)(k_uptime_get() / 1000),
		.location    = {
			.latitude_udeg  = (int32_t)(lat * 1e6),
			.longitude_udeg = (int32_t)(lon * 1e6),
			.fix_quality    = 1,
		},
	};
	LOG_WRN("Geofence %s: id=%u", btype == BREACH_EXIT ? "EXIT" : "ENTER", f->id);
	if (alert_cb) alert_cb(&alert);
}

/* ── Public API ─────────────────────────────────────────────────────────*/

int geofence_engine_init(void)
{
	memset(fences, 0, sizeof(fences));
	nvs_init();
	load_fences();
	LOG_INF("Geofence engine initialised");
	return 0;
}

int geofence_add_circle(uint8_t id, double lat, double lon, uint32_t radius_m)
{
	if (id >= MAX_GEOFENCES) return -EINVAL;
	if (radius_m < MIN_GEOFENCE_RADIUS_M || radius_m > MAX_GEOFENCE_RADIUS_M)
		return -ERANGE;
	k_mutex_lock(&geo_mutex, K_FOREVER);
	fence_t *f = &fences[id];
	f->id       = id;
	f->type     = FENCE_CIRCLE;
	f->active   = true;
	f->lat      = lat;
	f->lon      = lon;
	f->radius_m = (double)radius_m;
	f->pet_inside = false;
	save_fence(f);
	k_mutex_unlock(&geo_mutex);
	LOG_INF("Circle geofence added: id=%u lat=%.6f lon=%.6f r=%u m",
		id, lat, lon, radius_m);
	return 0;
}

int geofence_add_polygon(uint8_t id, const struct geofence_vertex *vertices,
			 uint8_t num_vertices)
{
	if (id >= MAX_GEOFENCES || !vertices) return -EINVAL;
	if (num_vertices < 3 || num_vertices > MAX_POLYGON_VERTICES) return -EINVAL;
	k_mutex_lock(&geo_mutex, K_FOREVER);
	fence_t *f = &fences[id];
	f->id        = id;
	f->type      = FENCE_POLYGON;
	f->active    = true;
	f->num_verts = num_vertices;
	f->pet_inside = false;
	memcpy(f->verts, vertices, num_vertices * sizeof(*vertices));
	save_fence(f);
	k_mutex_unlock(&geo_mutex);
	LOG_INF("Polygon geofence added: id=%u verts=%u", id, num_vertices);
	return 0;
}

int geofence_remove(uint8_t id)
{
	if (id >= MAX_GEOFENCES) return -EINVAL;
	k_mutex_lock(&geo_mutex, K_FOREVER);
	fences[id].active = false;
	if (nvs_ready) nvs_delete(&nvs, GEO_NVS_ID_BASE + id);
	k_mutex_unlock(&geo_mutex);
	LOG_INF("Geofence removed: id=%u", id);
	return 0;
}

void geofence_check_position(double lat, double lon)
{
	uint32_t now_s = (uint32_t)(k_uptime_get() / 1000);
	k_mutex_lock(&geo_mutex, K_FOREVER);
	for (uint8_t i = 0; i < MAX_GEOFENCES; i++) {
		fence_t *f = &fences[i];
		if (!f->active) continue;

		bool inside = false;
		if (f->type == FENCE_CIRCLE) {
			double dist = haversine_m(lat, lon, f->lat, f->lon);
			double eff_r = f->pet_inside
				? f->radius_m + GEOFENCE_HYSTERESIS_M
				: f->radius_m;
			inside = dist <= eff_r;
		} else if (f->type == FENCE_POLYGON) {
			inside = point_in_polygon(lat, lon,
						  f->verts, f->num_verts);
		}

		if (inside && !f->pet_inside) {
			/* Apply dwell time before announcing entry */
			if (f->entry_time_s == 0) {
				f->entry_time_s = now_s;
			} else if ((now_s - f->entry_time_s) >= DWELL_TIME_S) {
				f->pet_inside   = true;
				f->entry_time_s = 0;
				dispatch_alert(f, BREACH_ENTER, lat, lon);
			}
		} else if (!inside && f->pet_inside) {
			f->pet_inside   = false;
			f->entry_time_s = 0;
			dispatch_alert(f, BREACH_EXIT, lat, lon);
		} else if (!inside) {
			f->entry_time_s = 0; /* reset dwell timer */
		}
	}
	k_mutex_unlock(&geo_mutex);
}

void geofence_register_alert_callback(void (*cb)(const geofence_alert_t *alert))
{
	alert_cb = cb;
}
