/*
 * Copyright (c) 2024 Smart Pet Collar Tracker
 * SPDX-License-Identifier: Apache-2.0
 *
 * Cloud connector – MQTT over TLS 1.3 to AWS IoT Core.
 *
 * Topics:
 *   pet/{device_id}/telemetry  – QoS 0 (best-effort)
 *   pet/{device_id}/alert      – QoS 1 (guaranteed delivery)
 *   pet/{device_id}/command    – subscribed, QoS 1
 *   pet/{device_id}/shadow     – subscribed, QoS 0
 */

#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>
#include <zephyr/net/mqtt.h>
#include <zephyr/net/socket.h>
#include <zephyr/net/tls_credentials.h>
#include <zephyr/random/random.h>
#include <string.h>
#include <stdio.h>
#include <errno.h>
#include <modem/modem_info.h>

#include "cloud_connector.h"
#include "config.h"

LOG_MODULE_REGISTER(cloud_connector, LOG_LEVEL_INF);

/* ── TLS security tags ──────────────────────────────────────────────────*/
#define TLS_SEC_TAG_CA    1
#define TLS_SEC_TAG_CERT  2
#define TLS_SEC_TAG_KEY   3

/* ── Publish queue ──────────────────────────────────────────────────────*/
#define TX_QUEUE_DEPTH    10
#define TX_PAYLOAD_MAX    MQTT_PAYLOAD_MAX_SIZE

struct pub_msg {
	char    topic[MQTT_TOPIC_MAX_LEN];
	char    payload[TX_PAYLOAD_MAX];
	size_t  payload_len;
	uint8_t qos;
};

K_MSGQ_DEFINE(pub_queue, sizeof(struct pub_msg), TX_QUEUE_DEPTH, 4);

/* ── MQTT state ─────────────────────────────────────────────────────────*/
static struct mqtt_client      mqtt_client_ctx;
static struct sockaddr_storage broker_addr;
static uint8_t                 rx_buf[1024];
static uint8_t                 tx_buf[1024];
static char                    device_id[32];

static void (*command_cb)(const char *topic, const char *payload, size_t len);

static char topic_telemetry[MQTT_TOPIC_MAX_LEN];
static char topic_alert[MQTT_TOPIC_MAX_LEN];
static char topic_command[MQTT_TOPIC_MAX_LEN];
static char topic_shadow[MQTT_TOPIC_MAX_LEN];

static atomic_t mqtt_connected = ATOMIC_INIT(0);

/* ── Back-off ───────────────────────────────────────────────────────────*/
#define MQTT_BACKOFF_INITIAL_S   4
#define MQTT_BACKOFF_MAX_S       1800
static uint32_t mqtt_backoff_s = MQTT_BACKOFF_INITIAL_S;

static struct k_work_delayable mqtt_reconnect_work;
static struct k_work            mqtt_process_work;

/* ── MQTT thread ────────────────────────────────────────────────────────*/
#define MQTT_THREAD_STACK  MQTT_THREAD_STACK_SIZE
#define MQTT_THREAD_PRIO   5

K_THREAD_STACK_DEFINE(mqtt_thread_stack, MQTT_THREAD_STACK);
static struct k_thread mqtt_thread_data;

/* ── Helper: publish from queue entry ──────────────────────────────────*/
static int do_publish(const struct pub_msg *msg)
{
	struct mqtt_publish_param param = {
		.message = {
			.topic = {
				.topic = {
					.utf8   = (uint8_t *)msg->topic,
					.size   = strlen(msg->topic),
				},
				.qos = msg->qos,
			},
			.payload = {
				.data = (uint8_t *)msg->payload,
				.len  = msg->payload_len,
			},
		},
		.message_id    = (uint16_t)sys_rand32_get(),
		.dup_flag      = 0,
		.retain_flag   = 0,
	};

	int ret = mqtt_publish(&mqtt_client_ctx, &param);
	if (ret < 0) {
		LOG_ERR("MQTT publish failed: %d", ret);
	}
	return ret;
}

/* ── MQTT event handler ─────────────────────────────────────────────────*/
static void mqtt_evt_handler(struct mqtt_client *client,
			      const struct mqtt_evt *evt)
{
	int ret;

	switch (evt->type) {
	case MQTT_EVT_CONNACK:
		if (evt->result == 0) {
			LOG_INF("MQTT connected to %s", MQTT_BROKER_ENDPOINT);
			atomic_set(&mqtt_connected, 1);
			mqtt_backoff_s = MQTT_BACKOFF_INITIAL_S;
			cloud_subscribe_commands();
		} else {
			LOG_ERR("MQTT CONNACK error: %d", evt->result);
			atomic_set(&mqtt_connected, 0);
		}
		break;

	case MQTT_EVT_DISCONNECT:
		LOG_WRN("MQTT disconnected: %d", evt->result);
		atomic_set(&mqtt_connected, 0);
		k_work_schedule(&mqtt_reconnect_work,
				K_SECONDS(mqtt_backoff_s));
		mqtt_backoff_s = MIN(mqtt_backoff_s * 2U, MQTT_BACKOFF_MAX_S);
		break;

	case MQTT_EVT_PUBLISH: {
		const struct mqtt_publish_message *msg = &evt->param.publish.message;
		static char payload_buf[TX_PAYLOAD_MAX];
		size_t len = MIN(msg->payload.len, sizeof(payload_buf) - 1);

		ret = mqtt_readall_publish_payload(client,
						   (uint8_t *)payload_buf, len);
		if (ret < 0) {
			LOG_ERR("MQTT payload read failed: %d", ret);
			break;
		}
		payload_buf[len] = '\0';

		char topic_buf[MQTT_TOPIC_MAX_LEN];
		size_t tlen = MIN(msg->topic.topic.size, sizeof(topic_buf) - 1);
		memcpy(topic_buf, msg->topic.topic.utf8, tlen);
		topic_buf[tlen] = '\0';

		LOG_DBG("MQTT message on '%s': %zu bytes", topic_buf, len);

		if (command_cb) {
			command_cb(topic_buf, payload_buf, len);
		}

		if (msg->topic.qos == MQTT_QOS_1_AT_LEAST_ONCE) {
			struct mqtt_puback_param puback = {
				.message_id = evt->param.publish.message_id,
			};
			mqtt_publish_qos1_ack(client, &puback);
		}
		break;
	}

	case MQTT_EVT_PUBACK:
		LOG_DBG("MQTT PUBACK id=%u", evt->param.puback.message_id);
		break;

	case MQTT_EVT_SUBACK:
		LOG_INF("MQTT SUBACK id=%u", evt->param.suback.message_id);
		break;

	case MQTT_EVT_PINGRESP:
		LOG_DBG("MQTT PINGRESP");
		break;

	default:
		break;
	}
}

/* ── MQTT processing thread ─────────────────────────────────────────────*/
static void mqtt_thread_fn(void *arg1, void *arg2, void *arg3)
{
	struct pub_msg msg;
	int ret;

	while (true) {
		if (!atomic_get(&mqtt_connected)) {
			k_sleep(K_MSEC(100));
			continue;
		}

		/* Drain transmit queue */
		while (k_msgq_get(&pub_queue, &msg, K_NO_WAIT) == 0) {
			do_publish(&msg);
		}

		/* Run MQTT keep-alive */
		ret = mqtt_live(&mqtt_client_ctx);
		if (ret < 0 && ret != -EAGAIN) {
			LOG_ERR("mqtt_live failed: %d", ret);
		}

		/* Poll for incoming data with 500 ms timeout */
		struct zsock_pollfd fds = {
			.fd     = mqtt_client_ctx.transport.tls.sock,
			.events = ZSOCK_POLLIN,
		};
		ret = zsock_poll(&fds, 1, 500);
		if (ret > 0 && (fds.revents & ZSOCK_POLLIN)) {
			ret = mqtt_input(&mqtt_client_ctx);
			if (ret < 0) {
				LOG_ERR("mqtt_input failed: %d", ret);
			}
		}
	}
}

/* ── Reconnect work ─────────────────────────────────────────────────────*/
static void mqtt_reconnect_handler(struct k_work *work)
{
	cloud_connector_connect();
}

/* ── Public API ─────────────────────────────────────────────────────────*/

int cloud_connector_init(void)
{
	/* Derive device ID from IMEI */
	char imei[20] = "unknown";
	modem_info_string_get(MODEM_INFO_IMEI, imei, sizeof(imei));
	snprintf(device_id, sizeof(device_id), "%.15s", imei);

	snprintf(topic_telemetry, sizeof(topic_telemetry),
		 "pet/%s/telemetry", device_id);
	snprintf(topic_alert,     sizeof(topic_alert),
		 "pet/%s/alert",     device_id);
	snprintf(topic_command,   sizeof(topic_command),
		 "pet/%s/command",   device_id);
	snprintf(topic_shadow,    sizeof(topic_shadow),
		 "pet/%s/shadow",    device_id);

	/* Configure MQTT client */
	mqtt_client_init(&mqtt_client_ctx);

	mqtt_client_ctx.broker        = &broker_addr;
	mqtt_client_ctx.evt_cb        = mqtt_evt_handler;
	mqtt_client_ctx.client_id.utf8 = (uint8_t *)device_id;
	mqtt_client_ctx.client_id.size = strlen(device_id);
	mqtt_client_ctx.protocol_version = MQTT_VERSION_3_1_1;
	mqtt_client_ctx.rx_buf        = rx_buf;
	mqtt_client_ctx.rx_buf_size   = sizeof(rx_buf);
	mqtt_client_ctx.tx_buf        = tx_buf;
	mqtt_client_ctx.tx_buf_size   = sizeof(tx_buf);
	mqtt_client_ctx.keepalive     = MQTT_KEEPALIVE_S;

	/* TLS transport */
	struct mqtt_sec_config *tls = &mqtt_client_ctx.transport.tls.config;
	static const sec_tag_t sec_tag_list[] = {
		TLS_SEC_TAG_CA, TLS_SEC_TAG_CERT, TLS_SEC_TAG_KEY,
	};
	tls->peer_verify  = TLS_PEER_VERIFY_REQUIRED;
	tls->cipher_list  = NULL;
	tls->sec_tag_list = sec_tag_list;
	tls->sec_tag_count = ARRAY_SIZE(sec_tag_list);
	tls->hostname     = MQTT_BROKER_ENDPOINT;
	mqtt_client_ctx.transport.type = MQTT_TRANSPORT_SECURE;

	k_work_init_delayable(&mqtt_reconnect_work, mqtt_reconnect_handler);

	/* Start MQTT thread */
	k_thread_create(&mqtt_thread_data, mqtt_thread_stack,
			K_THREAD_STACK_SIZEOF(mqtt_thread_stack),
			mqtt_thread_fn, NULL, NULL, NULL,
			MQTT_THREAD_PRIO, 0, K_NO_WAIT);
	k_thread_name_set(&mqtt_thread_data, "mqtt");

	LOG_INF("Cloud connector initialised (device_id=%s)", device_id);
	return 0;
}

int cloud_connector_connect(void)
{
	struct zsock_addrinfo hints = {
		.ai_family   = AF_INET,
		.ai_socktype = SOCK_STREAM,
	};
	struct zsock_addrinfo *result;
	char port_str[8];

	snprintf(port_str, sizeof(port_str), "%u", MQTT_BROKER_PORT);

	int ret = zsock_getaddrinfo(MQTT_BROKER_ENDPOINT, port_str,
				    &hints, &result);
	if (ret < 0) {
		LOG_ERR("DNS lookup failed for %s: %d",
			MQTT_BROKER_ENDPOINT, ret);
		k_work_schedule(&mqtt_reconnect_work,
				K_SECONDS(mqtt_backoff_s));
		mqtt_backoff_s = MIN(mqtt_backoff_s * 2U, MQTT_BACKOFF_MAX_S);
		return ret;
	}

	memcpy(&broker_addr, result->ai_addr, result->ai_addrlen);
	zsock_freeaddrinfo(result);

	ret = mqtt_connect(&mqtt_client_ctx);
	if (ret < 0) {
		LOG_ERR("mqtt_connect failed: %d", ret);
		k_work_schedule(&mqtt_reconnect_work,
				K_SECONDS(mqtt_backoff_s));
		mqtt_backoff_s = MIN(mqtt_backoff_s * 2U, MQTT_BACKOFF_MAX_S);
	} else {
		LOG_INF("MQTT connecting to %s:%u",
			MQTT_BROKER_ENDPOINT, MQTT_BROKER_PORT);
	}
	return ret;
}

int cloud_connector_disconnect(void)
{
	int ret = mqtt_disconnect(&mqtt_client_ctx);
	if (ret < 0) {
		LOG_ERR("mqtt_disconnect failed: %d", ret);
	}
	atomic_set(&mqtt_connected, 0);
	return ret;
}

int cloud_publish_telemetry(const char *payload, size_t len)
{
	if (!payload || len == 0 || len >= TX_PAYLOAD_MAX) {
		return -EINVAL;
	}

	struct pub_msg msg;
	strncpy(msg.topic, topic_telemetry, sizeof(msg.topic) - 1);
	msg.topic[sizeof(msg.topic) - 1] = '\0';
	memcpy(msg.payload, payload, len);
	msg.payload[len] = '\0';
	msg.payload_len  = len;
	msg.qos          = MQTT_QOS_0_AT_MOST_ONCE;

	int ret = k_msgq_put(&pub_queue, &msg, K_NO_WAIT);
	if (ret < 0) {
		LOG_WRN("Telemetry queue full – dropping message");
		return -ENOMEM;
	}
	return 0;
}

int cloud_publish_alert(const char *payload, size_t len)
{
	if (!payload || len == 0 || len >= TX_PAYLOAD_MAX) {
		return -EINVAL;
	}

	struct pub_msg msg;
	strncpy(msg.topic, topic_alert, sizeof(msg.topic) - 1);
	msg.topic[sizeof(msg.topic) - 1] = '\0';
	memcpy(msg.payload, payload, len);
	msg.payload[len] = '\0';
	msg.payload_len  = len;
	msg.qos          = MQTT_QOS_1_AT_LEAST_ONCE;

	int ret = k_msgq_put(&pub_queue, &msg, K_NO_WAIT);
	if (ret < 0) {
		LOG_ERR("Alert queue full");
		return -ENOMEM;
	}
	return 0;
}

int cloud_subscribe_commands(void)
{
	struct mqtt_topic topics[2] = {
		{
			.topic = {
				.utf8 = (uint8_t *)topic_command,
				.size = strlen(topic_command),
			},
			.qos = MQTT_QOS_1_AT_LEAST_ONCE,
		},
		{
			.topic = {
				.utf8 = (uint8_t *)topic_shadow,
				.size = strlen(topic_shadow),
			},
			.qos = MQTT_QOS_0_AT_MOST_ONCE,
		},
	};

	struct mqtt_subscription_list sub_list = {
		.list       = topics,
		.list_count = ARRAY_SIZE(topics),
		.message_id = (uint16_t)sys_rand32_get(),
	};

	int ret = mqtt_subscribe(&mqtt_client_ctx, &sub_list);
	if (ret < 0) {
		LOG_ERR("MQTT subscribe failed: %d", ret);
	} else {
		LOG_INF("Subscribed to command and shadow topics");
	}
	return ret;
}

void cloud_register_command_callback(
	void (*cb)(const char *topic, const char *payload, size_t len))
{
	command_cb = cb;
}
