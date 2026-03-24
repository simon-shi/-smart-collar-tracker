/*
 * Copyright (c) 2024 Smart Pet Collar Tracker
 * SPDX-License-Identifier: Apache-2.0
 */

#ifndef FIRMWARE_NRF9160_OFFLINE_TRACK_H_
#define FIRMWARE_NRF9160_OFFLINE_TRACK_H_

#include <stdint.h>
#include <stdbool.h>
#include "pet_data.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Initialise the offline track log on external NOR flash.
 *
 * Reads the ring-buffer header from flash. If no valid header is found
 * (magic mismatch) the storage area is erased and a fresh header written.
 *
 * @return 0 on success, negative errno on failure.
 */
int offline_track_init(void);

/**
 * @brief Append a track record to the ring buffer.
 *
 * Erases the destination sector when the write pointer crosses a 4 kB
 * sector boundary.  Overwrites the oldest record when the ring is full.
 *
 * @param rec  Record to write.
 *
 * @return 0 on success, negative errno on failure.
 */
int offline_track_store(const flash_track_record_t *rec);

/**
 * @brief Check whether unread records are available.
 *
 * @return true if records can be read, false if the ring is empty.
 */
bool offline_track_has_data(void);

/**
 * @brief Read and consume the next available track record (FIFO order).
 *
 * Advances the read pointer after a successful read. The record is NOT
 * erased from flash; call offline_track_clear() to wipe all data.
 *
 * @param[out] rec  Populated with the next record.
 *
 * @return 0 on success, -ENODATA if no records remain, negative errno
 *         on flash read error.
 */
int offline_track_read_next(flash_track_record_t *rec);

/**
 * @brief Erase all offline track records and reset the ring buffer.
 *
 * Erases all sectors in the track partition and writes a fresh header.
 *
 * @return 0 on success, negative errno on failure.
 */
int offline_track_clear(void);

/**
 * @brief Return the number of unread records available.
 *
 * @return Number of records, or negative errno on failure.
 */
int offline_track_count(void);

#ifdef __cplusplus
}
#endif

#endif /* FIRMWARE_NRF9160_OFFLINE_TRACK_H_ */
