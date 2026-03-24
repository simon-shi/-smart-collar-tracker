# BLE GATT Service Specification

## Overview

The nRF52840 exposes three standard BLE profiles and one custom service:

| Service | UUID | Type |
|---------|------|------|
| Device Information Service | 0x180A | Standard (DIS) |
| Battery Service | 0x180F | Standard (BAS) |
| Pet Tracker Service | 128-bit (below) | Custom |
| SMP (MCUmgr OTA) | `8D53DC1D-1DB7-4CD3-868B-8A527460AA84` | MCUmgr |

---

## Device Information Service (DIS) – UUID 0x180A

| Characteristic | UUID | Properties | Value |
|---------------|------|-----------|-------|
| Manufacturer Name | 0x2A29 | Read | "SmartCollar Inc" |
| Model Number | 0x2A24 | Read | "SC-1" |
| Serial Number | 0x2A25 | Read | Device hardware ID |
| Hardware Revision | 0x2A27 | Read | "1.0" |
| Firmware Revision | 0x2A26 | Read | "1.0.0" |
| Software Revision | 0x2A28 | Read | "1.0.0" |

---

## Battery Service (BAS) – UUID 0x180F

| Characteristic | UUID | Properties | Format |
|---------------|------|-----------|--------|
| Battery Level | 0x2A19 | Read, Notify | uint8 (0–100 %) |

- Notifications sent when level changes by ≥ 5 % or once per 60 s
- Level below 10 % triggers a low-battery alert via MQTT

---

## Pet Tracker Service – UUID `12345678-1234-5678-1234-56789abcdef0`

All 128-bit UUIDs share the base `12345678-1234-5678-1234-56789abcdefX` where X is the characteristic index.

### Characteristic 1 – Location (Notify)
**UUID:** `12345678-1234-5678-1234-56789abcdef1`  
**Properties:** Notify  
**Length:** 26 bytes  

| Byte offset | Type | Field | Units |
|-------------|------|-------|-------|
| 0..3 | int32 LE | latitude_udeg | 10⁻⁶ ° |
| 4..7 | int32 LE | longitude_udeg | 10⁻⁶ ° |
| 8..11 | int32 LE | altitude_mm | mm |
| 12..15 | uint32 LE | speed_mmps | mm/s |
| 16..17 | uint16 LE | heading_cdeg | 0–35999 cdeg |
| 18..21 | uint32 LE | accuracy_mm | mm |
| 22..25 | uint32 LE | timestamp_s | Unix epoch s |
| 26 | uint8 | fix_quality | 0=no fix, 1=GPS |
| 27 | uint8 | satellites | count |

**Total: 26 bytes** (PET_LOCATION_SERIALISED_SIZE)

Notifications are sent after each successful GPS fix.

---

### Characteristic 2 – Activity (Notify)
**UUID:** `12345678-1234-5678-1234-56789abcdef2`  
**Properties:** Notify  
**Length:** 17 bytes  

| Byte offset | Type | Field | Notes |
|-------------|------|-------|-------|
| 0..3 | uint32 LE | steps | total step count |
| 4..7 | uint32 LE | calories_mcal | milli-calories |
| 8..11 | uint32 LE | duration_s | window duration |
| 12..15 | uint32 LE | timestamp_s | Unix epoch s |
| 16 | uint8 | activity_type | see enum below |

**Activity Type Enum:**
```
0 = REST
1 = WALK
2 = RUN
3 = PLAY
4 = SWIM
5 = SLEEP
```

Notifications sent every 60 s or on activity-type change.

---

### Characteristic 3 – Geofence Alert (Notify)
**UUID:** `12345678-1234-5678-1234-56789abcdef3`  
**Properties:** Notify  
**Length:** 32 bytes  

| Byte offset | Type | Field |
|-------------|------|-------|
| 0 | uint8 | fence_id (0-based) |
| 1 | uint8 | breach_type (0=ENTER, 1=EXIT) |
| 2..5 | uint32 LE | timestamp_s |
| 6..31 | – | location (26 bytes, same format as Characteristic 1) |

---

### Characteristic 4 – Device Control (Write)
**UUID:** `12345678-1234-5678-1234-56789abcdef4`  
**Properties:** Write, Write Without Response  
**Max length:** 20 bytes  

Command byte (byte 0) defines the control action:

| Cmd byte | Name | Payload |
|----------|------|---------|
| 0x01 | SET_LED_MODE | byte[1] = LED mode (0=off, 1=solid, 2=blink, 3=breathe, 4=SOS, 5=night_search) |
| 0x02 | SET_LED_COLOR | byte[1]=R, byte[2]=G, byte[3]=B |
| 0x03 | FIND_PET | byte[1] = duration_s (0 = stop) |
| 0x04 | SET_POWER_MODE | byte[1] = power_mode (0–3) |
| 0x05 | SET_GPS_INTERVAL | byte[1..4] = interval_s LE uint32 |
| 0x06 | TRIGGER_OFFLINE_SYNC | no payload |
| 0x07 | REBOOT | no payload |

---

### Characteristic 5 – Device Status (Read)
**UUID:** `12345678-1234-5678-1234-56789abcdef5`  
**Properties:** Read  
**Length:** 20 bytes  

| Byte offset | Type | Field |
|-------------|------|-------|
| 0 | uint8 | power_mode |
| 1 | uint8 | fw_version_major |
| 2 | uint8 | fw_version_minor |
| 3 | uint8 | fw_version_patch |
| 4..5 | int16 LE | rsrp_dbm |
| 6..7 | int16 LE | rsrq_db |
| 8 | uint8 | battery_percent |
| 9..10 | uint16 LE | battery_mv |
| 11 | uint8 | is_charging (bool) |
| 12..15 | uint32 LE | battery_timestamp_s |
| 16..19 | uint32 LE | uptime_s |

---

### Characteristic 6 – Offline Sync (Notify)
**UUID:** `12345678-1234-5678-1234-56789abcdef6`  
**Properties:** Notify  
**Length:** variable (up to ATT MTU - 3 bytes, typically 244 bytes)  

Used for bulk transfer of offline track records from flash to the phone app. Each notification contains one or more 18-byte compact track records (as many as fit in the ATT MTU).

Format: `N × 18 bytes` where N = floor((ATT_MTU - 3) / 18)

After all records are transferred, a zero-length notification is sent as end-of-stream marker.

---

## iBeacon Advertising

When not connected, the nRF52840 alternates between connectable advertising (10 s) and iBeacon non-connectable advertising (10 s).

### iBeacon Payload

```
AD Type: 0xFF (Manufacturer Specific)
Company ID:  0x004C (Apple Inc, LE)
Subtype:     0x02 0x15
Proximity UUID: FDA50693-A4E2-4FB1-AFCF-C6EB07647825 (default)
Major:       configurable (default 0x0001)
Minor:       configurable (default 0x0001)
TX Power:    –59 dBm (calibrated RSSI at 1 m)
```

The proximity UUID, major, and minor can be reconfigured via the Device Control characteristic (cmd 0x08, 18-byte payload: UUID[16] + major[2] LE + minor[2] LE).

---

## Security

| Parameter | Value |
|-----------|-------|
| Pairing method | LE Secure Connections (LESC) |
| Bonding | Yes (stored in NVS) |
| MITM protection | Yes (passkey or numeric comparison) |
| Encryption | AES-128-CCM |
| Max bonded devices | 2 |

All GATT characteristics except Device Status require an encrypted connection (bonded peer) to read or receive notifications. Write to Device Control requires encrypted + authenticated connection.

---

## Connection Parameters

| Parameter | Active | Idle |
|-----------|--------|------|
| Connection interval | 30–60 ms | 1000–2000 ms |
| Slave latency | 0 | 4 |
| Supervision timeout | 4 s | 6 s |

The phone app should request parameter update to idle values after 30 s of inactivity to extend battery life.
