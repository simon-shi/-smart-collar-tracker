/*
 * Copyright (c) 2024 Smart Pet Collar Tracker
 * SPDX-License-Identifier: Apache-2.0
 *
 * Flash Manager – W25Q128 QSPI NOR flash ring-buffer for offline GPS tracks.
 */

#ifndef NRF52840_FLASH_MANAGER_H_
#define NRF52840_FLASH_MANAGER_H_

#include <stdint.h>
#include <stdbool.h>
#include "../../../common/include/pet_data.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Initialise the flash manager.
 *
 * Mounts the W25Q128 QSPI device, reads (or creates) the ring-buffer
 * header, and prepares for read/write operations.
 *
 * @return 0 on success, negative error code on failure.
 */
int flash_manager_init(void);

/**
 * @brief Append one GPS track record to the ring buffer.
 *
 * If the ring buffer is full the oldest record is overwritten (true ring
 * semantics).
 *
 * @param rec  Record to write.
 * @return 0 on success, negative error code on failure.
 */
int flash_manager_write_track(const flash_track_record_t *rec);

/**
 * @brief Read and consume the oldest unread track record.
 *
 * @param rec  Buffer to receive the record.
 * @return 0 if a record was returned, -ENODATA if the buffer is empty,
 *         other negative codes on I/O error.
 */
int flash_manager_read_track(flash_track_record_t *rec);

/**
 * @brief Return true if the ring buffer contains at least one record.
 */
bool flash_manager_has_data(void);

/**
 * @brief Erase all stored track records (reset the ring buffer).
 *
 * @return 0 on success, negative error code on failure.
 */
int flash_manager_clear(void);

/**
 * @brief Query ring-buffer occupancy.
 *
 * @param[out] used   Number of records currently stored.
 * @param[out] total  Total ring-buffer capacity in records.
 * @return 0 on success.
 */
int flash_manager_get_stats(uint32_t *used, uint32_t *total);

#ifdef __cplusplus
}
#endif

#endif /* NRF52840_FLASH_MANAGER_H_ */
