/*
 * Copyright (c) 2024 Smart Pet Collar Tracker
 * SPDX-License-Identifier: Apache-2.0
 *
 * Flash Manager – W25Q128 QSPI ring-buffer implementation.
 *
 * Layout (16 MB device):
 *   Sector 0   : Header  (4 096 bytes)
 *   Sectors 1… : Data (each sector holds RECORDS_PER_SECTOR records)
 *
 * Header (little-endian):
 *   Offset  0 : uint32_t magic        (FLASH_LOG_MAGIC = 0x50435431)
 *   Offset  4 : uint32_t version      (1)
 *   Offset  8 : uint32_t write_ptr    (absolute record index, wraps)
 *   Offset 12 : uint32_t read_ptr     (absolute record index, wraps)
 *   Offset 16 : uint32_t total_cap    (total ring capacity in records)
 *   Offset 20 : uint32_t reserved[3]
 *   Offset 32+: sector erase counts   (uint16_t per data sector for wear levelling)
 */

#include "flash_manager.h"

#include <zephyr/kernel.h>
#include <zephyr/device.h>
#include <zephyr/drivers/flash.h>
#include <zephyr/storage/flash_map.h>
#include <zephyr/logging/log.h>
#include <string.h>

#include "../../../common/include/config.h"

LOG_MODULE_REGISTER(flash_mgr, LOG_LEVEL_INF);

/* -----------------------------------------------------------------------
 * Constants
 * -------------------------------------------------------------------- */
#define FLASH_DEVICE         DT_ALIAS(ext_flash)

#define TOTAL_FLASH_BYTES    (16UL * 1024UL * 1024UL)  /* W25Q128 = 16 MB  */
#define SECTOR_SIZE          FLASH_SECTOR_SIZE           /* 4 096 bytes      */
#define TOTAL_SECTORS        (TOTAL_FLASH_BYTES / SECTOR_SIZE) /* 4 096      */
#define HEADER_SECTOR        0
#define DATA_SECTOR_START    1
#define DATA_SECTORS         (TOTAL_SECTORS - DATA_SECTOR_START) /* 4 095   */
#define RECORDS_PER_SECTOR   (SECTOR_SIZE / FLASH_TRACK_RECORD_SIZE) /* 227 */
#define TOTAL_RECORDS        (DATA_SECTORS * RECORDS_PER_SECTOR)     /* ~930k*/

#define HEADER_OFFSET        (HEADER_SECTOR * SECTOR_SIZE)
#define DATA_OFFSET_START    (DATA_SECTOR_START * SECTOR_SIZE)

/* Header field byte offsets */
#define HDR_OFF_MAGIC        0
#define HDR_OFF_VERSION      4
#define HDR_OFF_WRITE_PTR    8
#define HDR_OFF_READ_PTR     12
#define HDR_OFF_TOTAL_CAP    16
#define HDR_OFF_RESERVED     20
#define HDR_OFF_ERASE_COUNTS 32

#define HEADER_VERSION       1U

/* -----------------------------------------------------------------------
 * Module state
 * -------------------------------------------------------------------- */
static const struct device *flash_dev;
static K_MUTEX_DEFINE(flash_mutex);

static uint32_t write_ptr;  /* absolute record index (wraps at TOTAL_RECORDS) */
static uint32_t read_ptr;   /* absolute record index (wraps at TOTAL_RECORDS)  */
static uint32_t count;      /* records currently stored                        */

static bool initialised;

/* -----------------------------------------------------------------------
 * Helpers
 * -------------------------------------------------------------------- */

static off_t record_to_offset(uint32_t record_idx)
{
	uint32_t idx = record_idx % TOTAL_RECORDS;
	uint32_t sector = DATA_SECTOR_START + (idx / RECORDS_PER_SECTOR);
	uint32_t within = (idx % RECORDS_PER_SECTOR) * FLASH_TRACK_RECORD_SIZE;

	return (off_t)(sector * SECTOR_SIZE + within);
}

static int header_write(void)
{
	uint8_t hdr[HDR_OFF_ERASE_COUNTS]; /* first 32 bytes */

	memset(hdr, 0, sizeof(hdr));

	uint32_t magic   = FLASH_LOG_MAGIC;
	uint32_t version = HEADER_VERSION;
	uint32_t cap     = TOTAL_RECORDS;

	memcpy(hdr + HDR_OFF_MAGIC,     &magic,     4);
	memcpy(hdr + HDR_OFF_VERSION,   &version,   4);
	memcpy(hdr + HDR_OFF_WRITE_PTR, &write_ptr, 4);
	memcpy(hdr + HDR_OFF_READ_PTR,  &read_ptr,  4);
	memcpy(hdr + HDR_OFF_TOTAL_CAP, &cap,       4);

	/* Erase header sector, then write */
	int err = flash_erase(flash_dev, HEADER_OFFSET, SECTOR_SIZE);

	if (err) {
		LOG_ERR("Header sector erase failed: %d", err);
		return err;
	}

	err = flash_write(flash_dev, HEADER_OFFSET, hdr, sizeof(hdr));
	if (err) {
		LOG_ERR("Header write failed: %d", err);
	}
	return err;
}

static int header_read(void)
{
	uint8_t hdr[HDR_OFF_ERASE_COUNTS];

	int err = flash_read(flash_dev, HEADER_OFFSET, hdr, sizeof(hdr));

	if (err) {
		return err;
	}

	uint32_t magic;

	memcpy(&magic, hdr + HDR_OFF_MAGIC, 4);

	if (magic != FLASH_LOG_MAGIC) {
		return -EINVAL; /* header not present */
	}

	memcpy(&write_ptr, hdr + HDR_OFF_WRITE_PTR, 4);
	memcpy(&read_ptr,  hdr + HDR_OFF_READ_PTR,  4);

	if (write_ptr >= read_ptr) {
		count = write_ptr - read_ptr;
	} else {
		count = TOTAL_RECORDS - read_ptr + write_ptr;
	}
	return 0;
}

/* Erase the data sector that contains record_idx if we're at the sector
 * boundary (i.e. first write into a fresh sector). */
static int maybe_erase_sector(uint32_t record_idx)
{
	uint32_t idx    = record_idx % TOTAL_RECORDS;
	uint32_t within = idx % RECORDS_PER_SECTOR;

	if (within != 0) {
		return 0; /* not at sector boundary */
	}

	uint32_t sector = DATA_SECTOR_START + (idx / RECORDS_PER_SECTOR);
	off_t    offset = (off_t)(sector * SECTOR_SIZE);

	LOG_DBG("Erasing data sector %u", sector);
	return flash_erase(flash_dev, offset, SECTOR_SIZE);
}

/* -----------------------------------------------------------------------
 * Public API
 * -------------------------------------------------------------------- */

int flash_manager_init(void)
{
	flash_dev = DEVICE_DT_GET(FLASH_DEVICE);

	if (!device_is_ready(flash_dev)) {
		LOG_ERR("External flash device not ready");
		return -ENODEV;
	}

	k_mutex_lock(&flash_mutex, K_FOREVER);

	int err = header_read();

	if (err) {
		LOG_INF("No valid header found – formatting flash");
		write_ptr = 0;
		read_ptr  = 0;
		count     = 0;
		err = header_write();
	} else {
		LOG_INF("Flash header loaded: write=%u read=%u count=%u",
			write_ptr, read_ptr, count);
	}

	k_mutex_unlock(&flash_mutex);
	initialised = (err == 0);
	return err;
}

int flash_manager_write_track(const flash_track_record_t *rec)
{
	if (!initialised || !rec) {
		return -EINVAL;
	}

	/* Serialise record to 18-byte compact format */
	uint8_t buf[FLASH_TRACK_RECORD_SIZE];

	memcpy(buf + 0,  &rec->latitude_udeg,  4);
	memcpy(buf + 4,  &rec->longitude_udeg, 4);
	memcpy(buf + 8,  &rec->altitude_m,     2);
	memcpy(buf + 10, &rec->timestamp_s,    4);
	buf[14] = rec->speed_kmh;
	buf[15] = rec->heading_deg_div2;
	buf[16] = rec->flags;
	buf[17] = rec->activity_type;

	k_mutex_lock(&flash_mutex, K_FOREVER);

	int err = maybe_erase_sector(write_ptr);

	if (err) {
		LOG_ERR("Sector erase failed: %d", err);
		k_mutex_unlock(&flash_mutex);
		return err;
	}

	off_t offset = record_to_offset(write_ptr);

	err = flash_write(flash_dev, offset, buf, sizeof(buf));
	if (err) {
		LOG_ERR("Flash write failed at 0x%08x: %d",
			(unsigned)offset, err);
		k_mutex_unlock(&flash_mutex);
		return err;
	}

	write_ptr = (write_ptr + 1) % TOTAL_RECORDS;

	if (count >= TOTAL_RECORDS) {
		/* Ring is full – advance read pointer (oldest overwritten) */
		read_ptr = (read_ptr + 1) % TOTAL_RECORDS;
	} else {
		count++;
	}

	/* Persist header every 64 writes to reduce erase wear */
	if ((write_ptr & 0x3F) == 0) {
		header_write();
	}

	k_mutex_unlock(&flash_mutex);
	return 0;
}

int flash_manager_read_track(flash_track_record_t *rec)
{
	if (!initialised || !rec) {
		return -EINVAL;
	}

	k_mutex_lock(&flash_mutex, K_FOREVER);

	if (count == 0) {
		k_mutex_unlock(&flash_mutex);
		return -ENODATA;
	}

	uint8_t buf[FLASH_TRACK_RECORD_SIZE];
	off_t   offset = record_to_offset(read_ptr);

	int err = flash_read(flash_dev, offset, buf, sizeof(buf));

	if (err) {
		LOG_ERR("Flash read failed at 0x%08x: %d",
			(unsigned)offset, err);
		k_mutex_unlock(&flash_mutex);
		return err;
	}

	memcpy(&rec->latitude_udeg,  buf + 0,  4);
	memcpy(&rec->longitude_udeg, buf + 4,  4);
	memcpy(&rec->altitude_m,     buf + 8,  2);
	memcpy(&rec->timestamp_s,    buf + 10, 4);
	rec->speed_kmh        = buf[14];
	rec->heading_deg_div2 = buf[15];
	rec->flags            = buf[16];
	rec->activity_type    = buf[17];

	read_ptr = (read_ptr + 1) % TOTAL_RECORDS;
	count--;

	header_write();

	k_mutex_unlock(&flash_mutex);
	return 0;
}

bool flash_manager_has_data(void)
{
	if (!initialised) {
		return false;
	}
	return (count > 0);
}

int flash_manager_clear(void)
{
	if (!initialised) {
		return -EINVAL;
	}

	k_mutex_lock(&flash_mutex, K_FOREVER);

	write_ptr = 0;
	read_ptr  = 0;
	count     = 0;

	int err = header_write();

	k_mutex_unlock(&flash_mutex);

	if (!err) {
		LOG_INF("Flash ring buffer cleared");
	}
	return err;
}

int flash_manager_get_stats(uint32_t *used, uint32_t *total)
{
	if (!used || !total) {
		return -EINVAL;
	}

	k_mutex_lock(&flash_mutex, K_FOREVER);
	*used  = count;
	*total = TOTAL_RECORDS;
	k_mutex_unlock(&flash_mutex);

	return 0;
}
