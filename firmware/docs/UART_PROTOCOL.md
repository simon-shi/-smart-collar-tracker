# Inter-chip UART Protocol Specification

## Physical Layer

| Parameter | Value |
|-----------|-------|
| Interface | UART (async, hardware flow control RTS/CTS) |
| Baud rate | 1,000,000 bps |
| Data bits | 8 |
| Parity | None |
| Stop bits | 1 |
| Flow control | RTS/CTS hardware |
| Logic level | 1.8 V (nRF9160) ↔ 3.3 V (nRF52840) via level shifter |

---

## Packet Format

All multi-byte fields are **little-endian**.

```
 ┌────────┬──────────┬──────────┬────────┬────────┬─────────────┬──────────┐
 │  SOF   │ Length   │ Length   │  Cmd   │ SeqNo  │  Payload    │  CRC16   │
 │ 1 byte │ lo byte  │ hi byte  │ 1 byte │ 1 byte │  0–512 B    │ 2 bytes  │
 │ 0xAA   │  LE u16  │          │ enum   │ u8     │ (variable)  │ LE u16   │
 └────────┴──────────┴──────────┴────────┴────────┴─────────────┴──────────┘
   [0]      [1]        [2]        [3]      [4]      [5..5+N-1]   [5+N, 5+N+1]
```

- **SOF**: Start-of-frame byte, always `0xAA`
- **Length** (2 bytes LE): number of payload bytes (0–512)
- **Cmd** (1 byte): command identifier (see table below)
- **SeqNo** (1 byte): sequence number 0–255, wraps around; used for ACK correlation
- **Payload** (0–512 bytes): command-specific data
- **CRC16** (2 bytes LE): CRC16-CCITT over Cmd + SeqNo + Payload bytes

### CRC16-CCITT

- Polynomial: `0x1021`
- Initial value: `0xFFFF`
- No reflection, no final XOR
- Coverage: bytes [3] (Cmd) through [5+N-1] (last payload byte)

---

## Command Reference

| Cmd | Value | Direction | Description |
|-----|-------|-----------|-------------|
| CMD_GPS_DATA | 0x01 | 9160 → 52840 | GPS fix result |
| CMD_ACTIVITY_DATA | 0x02 | 9160 → 52840 | Activity classification |
| CMD_GEOFENCE_ALERT | 0x03 | 9160 → 52840 | Geofence breach event |
| CMD_LED_CONTROL | 0x04 | 52840 → 9160 | LED mode/colour command |
| CMD_FIND_PET | 0x05 | 52840 → 9160 | Find-pet mode trigger |
| CMD_CONFIG_SYNC | 0x06 | either | Configuration update |
| CMD_STATUS_REQ | 0x07 | 52840 → 9160 | Request status snapshot |
| CMD_STATUS_RESP | 0x08 | 9160 → 52840 | Status response |
| CMD_DFU_DATA | 0x09 | 52840 → 9160 | nRF9160 DFU image block |
| CMD_POWER_MODE | 0x0A | either | Power mode change |
| CMD_OFFLINE_SYNC | 0x0B | 52840 → 9160 | Trigger offline sync |
| CMD_HEALTH_DATA | 0x0C | 9160 → 52840 | Health sensor data |
| CMD_ACK | 0xFE | either | Positive acknowledgement |
| CMD_NACK | 0xFF | either | Negative acknowledgement |

---

## Payload Definitions

### CMD_GPS_DATA (0x01) – 26 bytes

Sent after each GPS fix; content is the serialised `pet_location_t`:

| Offset | Type | Field |
|--------|------|-------|
| 0..3 | int32 LE | latitude_udeg |
| 4..7 | int32 LE | longitude_udeg |
| 8..11 | int32 LE | altitude_mm |
| 12..15 | uint32 LE | speed_mmps |
| 16..17 | uint16 LE | heading_cdeg |
| 18..21 | uint32 LE | accuracy_mm |
| 22..25 | uint32 LE | timestamp_s |
| 26 | uint8 | fix_quality |
| 27 | uint8 | satellites |

---

### CMD_ACTIVITY_DATA (0x02) – 17 bytes

Serialised `pet_activity_data_t`:

| Offset | Type | Field |
|--------|------|-------|
| 0..3 | uint32 LE | steps |
| 4..7 | uint32 LE | calories_mcal |
| 8..11 | uint32 LE | duration_s |
| 12..15 | uint32 LE | timestamp_s |
| 16 | uint8 | activity_type |

---

### CMD_GEOFENCE_ALERT (0x03) – 32 bytes

Serialised `geofence_alert_t` (fence_id + breach_type + timestamp + location):

| Offset | Type | Field |
|--------|------|-------|
| 0 | uint8 | fence_id |
| 1 | uint8 | breach_type (0=ENTER, 1=EXIT) |
| 2..5 | uint32 LE | timestamp_s |
| 6..31 | – | location (26 bytes, same as GPS_DATA) |

---

### CMD_LED_CONTROL (0x04) – 5 bytes

| Offset | Type | Field |
|--------|------|-------|
| 0 | uint8 | pattern (0=off, 1=solid, 2=blink, 3=breathe, 4=SOS, 5=night_search, 6=rainbow) |
| 1 | uint8 | red (0–255) |
| 2 | uint8 | green (0–255) |
| 3 | uint8 | blue (0–255) |
| 4 | uint8 | brightness (0–255) |

---

### CMD_FIND_PET (0x05) – 1 byte

| Offset | Type | Field |
|--------|------|-------|
| 0 | uint8 | duration_s (0 = stop, 255 = indefinite) |

---

### CMD_CONFIG_SYNC (0x06) – variable

TLV (Type-Length-Value) encoded configuration items:

```
[type:1][len:1][value:len] ...
```

| Type | Meaning | Value format |
|------|---------|-------------|
| 0x01 | GPS fix interval (s) | uint32 LE |
| 0x02 | LTE report interval (s) | uint32 LE |
| 0x03 | Geofence config (add) | fence_id(1)+type(1)+lat(4)+lon(4)+radius_m(4) |
| 0x04 | Geofence remove | fence_id(1) |
| 0x05 | Power mode | uint8 |
| 0x06 | Pet weight (g) | uint16 LE |

---

### CMD_STATUS_REQ (0x07) – 0 bytes (no payload)

---

### CMD_STATUS_RESP (0x08) – 20 bytes

Serialised `device_status_t`:

| Offset | Type | Field |
|--------|------|-------|
| 0 | uint8 | power_mode |
| 1 | uint8 | fw_major |
| 2 | uint8 | fw_minor |
| 3 | uint8 | fw_patch |
| 4..5 | int16 LE | rsrp_dbm |
| 6..7 | int16 LE | rsrq_db |
| 8 | uint8 | battery_percent |
| 9..10 | uint16 LE | battery_mv |
| 11 | uint8 | is_charging |
| 12..15 | uint32 LE | battery_timestamp_s |
| 16..19 | uint32 LE | uptime_s |

---

### CMD_DFU_DATA (0x09) – 260 bytes

| Offset | Type | Field |
|--------|------|-------|
| 0..3 | uint32 LE | block_offset (byte offset into image) |
| 4..5 | uint16 LE | block_len |
| 6..261 | uint8[256] | image data |

---

### CMD_POWER_MODE (0x0A) – 1 byte

| Offset | Type | Field |
|--------|------|-------|
| 0 | uint8 | power_mode (0=DEEP_SLEEP, 1=LOW_POWER, 2=ACTIVE, 3=TRACKING) |

---

### CMD_OFFLINE_SYNC (0x0B) – 0 bytes (trigger) or variable (data)

When sent from nRF52840 → nRF9160 with no payload: trigger sync of NOR flash data to cloud.

When sent from nRF9160 → nRF52840 (batch of records):
- Payload: N × 18-byte compact track records (same layout as flash storage)

---

### CMD_HEALTH_DATA (0x0C) – 9 bytes

Serialised `pet_health_data_t`:

| Offset | Type | Field |
|--------|------|-------|
| 0..1 | int16 LE | temperature_cdegC |
| 2..3 | uint16 LE | heart_rate_bpm |
| 4 | uint8 | anomaly_flags |
| 5..8 | uint32 LE | timestamp_s |

---

### CMD_ACK (0xFE) – 1 byte

| Offset | Type | Field |
|--------|------|-------|
| 0 | uint8 | acknowledged_seq_no |

---

### CMD_NACK (0xFF) – 2 bytes

| Offset | Type | Field |
|--------|------|-------|
| 0 | uint8 | failed_seq_no |
| 1 | uint8 | reason (1=unknown_cmd, 2=invalid_len, 3=crc_error, 4=busy, 5=invalid_param) |

---

## Reliability

- Commands sent with SeqNo 0–255 (wrapping)
- Receiver sends CMD_ACK within 50 ms for QoS-1 commands (GPS, alerts, DFU)
- Sender retries up to 3 times with 50 ms back-off before declaring failure
- CMD_GPS_DATA and CMD_ACTIVITY_DATA are fire-and-forget (no retry)
- CMD_DFU_DATA and CMD_CONFIG_SYNC require ACK

---

## Flow Control

RTS/CTS hardware flow control prevents buffer overflow. Additionally:
- TX message queue depth: 16 packets
- If queue full, oldest non-critical packets are dropped with a warning log

---

## Timing

| Event | Max latency |
|-------|------------|
| GPS fix → BLE notification | < 100 ms |
| BLE control command → LED response | < 50 ms |
| ACK response | < 50 ms |
| DFU block ACK | < 200 ms |
