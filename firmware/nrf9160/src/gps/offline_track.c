/*
 * Copyright (c) 2024 Smart Pet Collar Tracker
 * SPDX-License-Identifier: Apache-2.0
 *
 * Offline GPS track log stored as a ring buffer in external NOR flash.
 *
 * Flash layout (track_partition, 512 kB):
 *   Sector 0  (4 kB)  : ring-buffer header
 *   Sectors 1-127     : track records, packed without gaps
 *
 * Header layout (stored at offset 0 within sector 0):
 *   Offset  0 : uint32_t magic       (FLASH_LOG_MAGIC = 0x50435431)
 *   Offset  4 : uint32_t write_idx   (record index of next write slot)
 *   Offset  8 : uint32_t read_idx    (record index of next unread record)
 *   Offset 12 : uint32_t total_count (total records ever written, wraps)
 *   Offset 16 : uint16_t crc16       (CRC over bytes 0–15)
 *
 * Records occupy sectors 1 onward; each FLASH_SECTOR_SIZE / FLASH_TRACK_RECORD_SIZE
 * records per sector.  The ring wraps at FLASH_MAX_TRACK_RECORDS.
 */

#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>
#include <zephyr/drivers/flash.h>
#include <zephyr/storage/flash_map.h>
#include <string.h>

#include "offline_track.h"
#include "config.h"
#include "protocol.h"

LOG_MODULE_REGISTER(offline_track, LOG_LEVEL_INF);

/* ── Flash partition ──────────────────────────────────────────────────────*/
#define TRACK_PARTITION_ID  FIXED_PARTITION_ID(track_partition)

/* Sector 0 holds the header; data starts at sector 1. */
#define HEADER_OFFSET       0
#define HEADER_SIZE         18U   /* magic(4)+write_idx(4)+read_idx(4)+count(4)+crc(2) */
#define DATA_START_OFFSET   FLASH_SECTOR_SIZE

/* Records per 4 kB sector */
#define RECORDS_PER_SECTOR  (FLASH_SECTOR_SIZE / FLASH_TRACK_RECORD_SIZE)

/* Total data sectors */
#define DATA_SECTORS        ((FLASH_TRACK_STORAGE_SIZE / FLASH_SECTOR_SIZE) - 1U)

/* Maximum records in data area */
#define MAX_RECORDS         (DATA_SECTORS * RECORDS_PER_SECTOR)

/* ── Ring-buffer state (RAM shadow of flash header) ───────────────────────*/
static struct {
	uint32_t write_idx;
	uint32_t read_idx;
	uint32_t total_count;
} ring;

static const struct flash_area *fa;
static K_MUTEX_DEFINE(track_mutex);
static bool initialised;

/* ── Header CRC ───────────────────────────────────────────────────────────*/
static uint16_t header_crc(uint32_t magic, uint32_t write_idx,
			    uint32_t read_idx, uint32_t count)
{
	uint8_t buf[16];
	uint32_t v;

	v = magic;      memcpy(&buf[0],  &v, 4);
	v = write_idx;  memcpy(&buf[4],  &v, 4);
	v = read_idx;   memcpy(&buf[8],  &v, 4);
	v = count;      memcpy(&buf[12], &v, 4);
	return crc16_ccitt(buf, 16);
}

/* ── Low-level helpers ────────────────────────────────────────────────────*/

/** Convert a record index to a byte offset within the flash partition. */
static off_t record_offset(uint32_t idx)
{
	return (off_t)(DATA_START_OFFSET +
		       (idx % MAX_RECORDS) * FLASH_TRACK_RECORD_SIZE);
}

static int write_header(void)
{
	uint8_t buf[HEADER_SIZE];
	uint32_t magic = FLASH_LOG_MAGIC;
	uint16_t crc   = header_crc(magic, ring.write_idx,
				     ring.read_idx, ring.total_count);
	memcpy(&buf[0],  &magic,           4);
	memcpy(&buf[4],  &ring.write_idx,  4);
	memcpy(&buf[8],  &ring.read_idx,   4);
	memcpy(&buf[12], &ring.total_count,4);
	memcpy(&buf[16], &crc,             2);

	/* Header sector must be erased before write */
	int ret = flash_area_erase(fa, HEADER_OFFSET, FLASH_SECTOR_SIZE);
	if (ret < 0) {
		LOG_ERR("Header sector erase failed: %d", ret);
		return ret;
	}
	ret = flash_area_write(fa, HEADER_OFFSET, buf, HEADER_SIZE);
	if (ret < 0) {
		LOG_ERR("Header write failed: %d", ret);
	}
	return ret;
}

static int read_header(void)
{
	uint8_t buf[HEADER_SIZE];
	uint32_t magic, write_idx, read_idx, count;
	uint16_t stored_crc, calc_crc;

	int ret = flash_area_read(fa, HEADER_OFFSET, buf, HEADER_SIZE);
	if (ret < 0) {
		return ret;
	}

	memcpy(&magic,     &buf[0],  4);
	memcpy(&write_idx, &buf[4],  4);
	memcpy(&read_idx,  &buf[8],  4);
	memcpy(&count,     &buf[12], 4);
	memcpy(&stored_crc,&buf[16], 2);

	if (magic != FLASH_LOG_MAGIC) {
		return -ENOENT;
	}

	calc_crc = header_crc(magic, write_idx, read_idx, count);
	if (calc_crc != stored_crc) {
		LOG_WRN("Header CRC mismatch: stored=0x%04X calc=0x%04X",
			stored_crc, calc_crc);
		return -EILSEQ;
	}

	ring.write_idx   = write_idx;
	ring.read_idx    = read_idx;
	ring.total_count = count;
	return 0;
}

/* Erase the data sector that contains a given record index if it has not
 * already been erased in this pass (detected by checking the first byte). */
static int maybe_erase_sector(uint32_t idx)
{
	off_t sector_base = DATA_START_OFFSET +
			    ((idx % MAX_RECORDS) / RECORDS_PER_SECTOR) *
			    (off_t)FLASH_SECTOR_SIZE;
	/* Check first byte of the sector */
	uint8_t first;
	int ret = flash_area_read(fa, sector_base, &first, 1);
	if (ret < 0) {
		return ret;
	}
	if (first != 0xFF) {
		ret = flash_area_erase(fa, sector_base, FLASH_SECTOR_SIZE);
		if (ret < 0) {
			LOG_ERR("Data sector erase @0x%lx failed: %d",
				(long)sector_base, ret);
		}
	}
	return ret;
}

/* ── Public API ───────────────────────────────────────────────────────────*/

int offline_track_init(void)
{
	int ret;

	ret = flash_area_open(TRACK_PARTITION_ID, &fa);
	if (ret < 0) {
		LOG_ERR("Flash area open failed: %d", ret);
		return ret;
	}

	ret = read_header();
	if (ret < 0) {
		LOG_WRN("No valid header – formatting track storage");
		ring.write_idx   = 0;
		ring.read_idx    = 0;
		ring.total_count = 0;
		ret = write_header();
		if (ret < 0) {
			return ret;
		}
	}

	initialised = true;
	LOG_INF("Offline track ready: write=%u read=%u total=%u",
		ring.write_idx, ring.read_idx, ring.total_count);
	return 0;
}

int offline_track_store(const flash_track_record_t *rec)
{
	if (!initialised || !rec) {
		return -EINVAL;
	}

	k_mutex_lock(&track_mutex, K_FOREVER);

	/* Erase sector when the write pointer lands on a sector boundary */
	if ((ring.write_idx % RECORDS_PER_SECTOR) == 0) {
		int ret = maybe_erase_sector(ring.write_idx);
		if (ret < 0) {
			k_mutex_unlock(&track_mutex);
			return ret;
		}
	}

	uint8_t buf[FLASH_TRACK_RECORD_SIZE];
	memcpy(&buf[FLASH_TR_OFFSET_LAT],       &rec->latitude_udeg,    4);
	memcpy(&buf[FLASH_TR_OFFSET_LON],       &rec->longitude_udeg,   4);
	memcpy(&buf[FLASH_TR_OFFSET_ALT],       &rec->altitude_m,       2);
	memcpy(&buf[FLASH_TR_OFFSET_TIMESTAMP], &rec->timestamp_s,      4);
	buf[FLASH_TR_OFFSET_SPEED]    = rec->speed_kmh;
	buf[FLASH_TR_OFFSET_HEADING]  = rec->heading_deg_div2;
	buf[FLASH_TR_OFFSET_FLAGS]    = rec->flags;
	buf[FLASH_TR_OFFSET_ACTIVITY] = rec->activity_type;

	int ret = flash_area_write(fa, record_offset(ring.write_idx),
				   buf, FLASH_TRACK_RECORD_SIZE);
	if (ret < 0) {
		LOG_ERR("Record write failed: %d", ret);
		k_mutex_unlock(&track_mutex);
		return ret;
	}

	ring.write_idx = (ring.write_idx + 1) % MAX_RECORDS;
	ring.total_count++;

	/* If ring is full, advance read pointer to discard oldest record */
	uint32_t used = (ring.write_idx >= ring.read_idx)
			? (ring.write_idx - ring.read_idx)
			: (MAX_RECORDS - ring.read_idx + ring.write_idx);
	if (used >= MAX_RECORDS) {
		ring.read_idx = (ring.read_idx + 1) % MAX_RECORDS;
	}

	ret = write_header();
	k_mutex_unlock(&track_mutex);
	return ret;
}

bool offline_track_has_data(void)
{
	if (!initialised) {
		return false;
	}
	return ring.read_idx != ring.write_idx;
}

int offline_track_read_next(flash_track_record_t *rec)
{
	if (!initialised || !rec) {
		return -EINVAL;
	}
	if (!offline_track_has_data()) {
		return -ENODATA;
	}

	k_mutex_lock(&track_mutex, K_FOREVER);

	uint8_t buf[FLASH_TRACK_RECORD_SIZE];
	int ret = flash_area_read(fa, record_offset(ring.read_idx),
				  buf, FLASH_TRACK_RECORD_SIZE);
	if (ret < 0) {
		LOG_ERR("Record read failed: %d", ret);
		k_mutex_unlock(&track_mutex);
		return ret;
	}

	memcpy(&rec->latitude_udeg,  &buf[FLASH_TR_OFFSET_LAT],       4);
	memcpy(&rec->longitude_udeg, &buf[FLASH_TR_OFFSET_LON],       4);
	memcpy(&rec->altitude_m,     &buf[FLASH_TR_OFFSET_ALT],       2);
	memcpy(&rec->timestamp_s,    &buf[FLASH_TR_OFFSET_TIMESTAMP], 4);
	rec->speed_kmh        = buf[FLASH_TR_OFFSET_SPEED];
	rec->heading_deg_div2 = buf[FLASH_TR_OFFSET_HEADING];
	rec->flags            = buf[FLASH_TR_OFFSET_FLAGS];
	rec->activity_type    = buf[FLASH_TR_OFFSET_ACTIVITY];

	ring.read_idx = (ring.read_idx + 1) % MAX_RECORDS;
	ret = write_header();

	k_mutex_unlock(&track_mutex);
	return ret;
}

int offline_track_clear(void)
{
	if (!initialised) {
		return -EINVAL;
	}

	k_mutex_lock(&track_mutex, K_FOREVER);

	/* Erase entire partition */
	int ret = flash_area_erase(fa, 0,
				   FLASH_SECTOR_SIZE * (DATA_SECTORS + 1));
	if (ret < 0) {
		LOG_ERR("Track clear erase failed: %d", ret);
		k_mutex_unlock(&track_mutex);
		return ret;
	}

	ring.write_idx   = 0;
	ring.read_idx    = 0;
	ring.total_count = 0;
	ret = write_header();

	k_mutex_unlock(&track_mutex);
	LOG_INF("Offline track cleared");
	return ret;
}

int offline_track_count(void)
{
	if (!initialised) {
		return -EINVAL;
	}
	if (ring.write_idx >= ring.read_idx) {
		return (int)(ring.write_idx - ring.read_idx);
	}
	return (int)(MAX_RECORDS - ring.read_idx + ring.write_idx);
}
