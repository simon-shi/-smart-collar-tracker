/*
 * Copyright (c) 2024 Smart Pet Collar Tracker
 * SPDX-License-Identifier: Apache-2.0
 */

#ifndef FIRMWARE_NRF9160_CLOUD_CONNECTOR_H_
#define FIRMWARE_NRF9160_CLOUD_CONNECTOR_H_

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Initialise the cloud connector.
 *
 * Configures the MQTT client with TLS credentials and registers topics.
 * Does not connect until cloud_connector_connect() is called.
 *
 * @return 0 on success, negative errno on failure.
 */
int cloud_connector_init(void);

/**
 * @brief Establish a TLS/MQTT connection to the cloud broker.
 *
 * Attempts connection; retries with exponential back-off on failure.
 * Calls cloud_subscribe_commands() automatically on successful connect.
 *
 * @return 0 if connection was initiated, negative errno on failure.
 */
int cloud_connector_connect(void);

/**
 * @brief Gracefully disconnect from the cloud broker.
 *
 * @return 0 on success, negative errno on failure.
 */
int cloud_connector_disconnect(void);

/**
 * @brief Publish a telemetry JSON payload to pet/{id}/telemetry (QoS 0).
 *
 * The payload is queued; actual transmission happens on the MQTT thread.
 *
 * @param payload  NULL-terminated JSON string.
 * @param len      Length of payload in bytes (excluding NUL).
 *
 * @return 0 on success, -ENOMEM if queue is full, negative errno otherwise.
 */
int cloud_publish_telemetry(const char *payload, size_t len);

/**
 * @brief Publish an alert JSON payload to pet/{id}/alert (QoS 1).
 *
 * @param payload  NULL-terminated JSON string.
 * @param len      Length of payload in bytes (excluding NUL).
 *
 * @return 0 on success, negative errno on failure.
 */
int cloud_publish_alert(const char *payload, size_t len);

/**
 * @brief Subscribe to the device command topic pet/{id}/command.
 *
 * @return 0 on success, negative errno on failure.
 */
int cloud_subscribe_commands(void);

/**
 * @brief Register a callback for incoming cloud commands.
 *
 * @param cb  Callback invoked with topic, payload pointer, and payload length.
 *            Called from the MQTT processing thread.
 */
void cloud_register_command_callback(
	void (*cb)(const char *topic, const char *payload, size_t len));

#ifdef __cplusplus
}
#endif

#endif /* FIRMWARE_NRF9160_CLOUD_CONNECTOR_H_ */
