# Firmware Architecture

## System Overview

The Smart Pet Collar firmware runs on a dual-chip architecture:

| Chip | Role | Key Peripherals |
|------|------|-----------------|
| Nordic nRF9160 | Cellular modem + GNSS | LTE-M/NB-IoT, GPS, I2C (LSM6DSO), SPI (W25Q128), UART |
| Nordic nRF52840 | BLE + sensor hub | BLE 5.0, QSPI (W25Q128), UART, USB CDC ACM |

Both chips communicate over a 1 Mbps UART link using the custom packet protocol defined in `common/include/protocol.h`.

---

## Repository Structure

```
firmware/
├── common/                   # Shared between both chips
│   ├── include/
│   │   ├── protocol.h        # Inter-chip UART packet protocol
│   │   ├── pet_data.h        # Shared data structures
│   │   └── config.h          # Global constants
│   └── src/
│       ├── protocol.c        # CRC16-CCITT, encode, decode
│       └── pet_data.c        # Serialisation helpers
│
├── nrf9160/                  # Cellular + GNSS firmware
│   └── src/
│       ├── gps/              # GNSS controller + offline track
│       ├── lte/              # LTE-M/NB-IoT manager
│       ├── cloud/            # MQTT/TLS → AWS IoT Core + codec
│       ├── sensors/          # LSM6DSO driver + activity classifier
│       ├── geofence/         # Circular/polygon geofence engine
│       ├── power/            # 4-level power state machine
│       ├── led/              # RGB + white LED controller
│       └── uart_bridge/      # Inter-chip protocol handler
│
├── nrf52840/                 # BLE firmware
│   └── src/
│       ├── ble/              # BLE stack, GATT services, beacon
│       ├── dfu/              # SMP OTA over BLE
│       ├── flash/            # W25Q128 ring buffer
│       ├── charge/           # Magnetic connector + charge state
│       └── uart_bridge/      # Inter-chip protocol handler
│
├── docs/                     # This documentation
└── scripts/                  # Build and flash automation
```

---

## Data Flow

```
LSM6DSO IMU
    │  I2C  (nRF9160)
    ▼
Activity Classifier ──► Step count, activity type, calorie estimate
    │
    ├──► Power Manager (wake-on-motion → GPS fix)
    │
    └──► UART Bridge ──► nRF52840 ──► BLE notification to phone app
              ▲
GPS (nrf_modem_gnss)
    │  nRF9160 modem
    ▼
GPS Controller
    ├── fix valid + LTE connected ──► Cloud Connector ──► AWS IoT Core (MQTT/TLS)
    └── fix valid + LTE down      ──► Offline Track   ──► NOR Flash ring buffer
                                                              │
                                             (on reconnect) ──► Cloud sync
Geofence Engine ◄── GPS fix
    └── breach detected ──► UART ──► nRF52840 BLE alert + cloud alert

nRF52840 BLE Manager
    ├── Connected phone ──► Pet Tracker GATT Service (notifications)
    ├── Not connected   ──► iBeacon advertising (crowd-sourced finding)
    └── OTA update      ──► DFU Manager ──► MCUboot slot1 write
```

---

## Power State Machine (nRF9160)

```
                    motion / geofence / command
DEEP_SLEEP ──────────────────────────────────────► ACTIVE
(~8 μA)        ◄──────── long inactivity ──────────
    │                                                │
    │  no motion,                                    │ SOS / find
    │  long time                                     ▼
    ▼                                           TRACKING
LOW_POWER ──────── motion detected ──────────────►  (10s GPS, 15s LTE)
(GPS 30 min)   ◄── inactivity ────────────────────
```

| State | GPS Interval | LTE Interval | Current (est.) |
|-------|-------------|-------------|----------------|
| DEEP_SLEEP | Off | 12 h PSM | ~8 μA |
| LOW_POWER | 30 min | 1 h | ~200 μA avg |
| ACTIVE | 60 s | 2 min | ~2 mA avg |
| TRACKING | 10 s | 15 s | ~30 mA avg |

---

## GNSS Strategy

- **Cold start**: uses A-GPS data injected from cloud (< 5 s TTFF)
- **Warm start**: last known almanac + ephemeris cached in modem
- **Wake-on-motion**: LSM6DSO INT1 wakes nRF9160 for opportunistic fix
- **Offline mode**: when LTE unavailable, fixes stored in 18-byte compact records in NOR flash ring buffer (capacity ~930,000 records @ 16 MB)

---

## LTE Connection Management

```
Boot
 │
 ▼
Modem init (nrf_modem_lib_init)
 │
 ▼
AT+CEREG subscribe
 │
 ▼
LTE-M search (60 s timeout) ─► NB-IoT fallback (60 s)
 │                                    │
 ▼ connected                          ▼ connected
PSM config: T3412=12h T3324=10s    same
 │
 ▼
eDRX config: 40.96 s cycle
 │
 ▼
MQTT connect → subscribe pet/{id}/command
 │
 ▼
Normal operation (publish telemetry / alerts)
 │
 ▼ on disconnect
Exponential backoff: 30s → 60s → 120s → … → 64min (cap)
```

---

## BLE Architecture (nRF52840)

- Stack: Zephyr Bluetooth subsystem (SoftDevice Controller replaced by open-source controller)
- Security: LE Secure Connections (LESC), bonding, MITM protection
- Max connections: 2 simultaneous
- Custom GATT service: see `BLE_PROTOCOL.md`
- SMP OTA: MCUmgr over BLE transport (`CONFIG_MCUMGR_TRANSPORT_BT=y`)
- iBeacon: alternates with connectable advertising when not paired (10 s period)

---

## Flash Ring Buffer (W25Q128)

```
┌─────────────────────────────────────────────────┐
│ Sector 0       Header (4 096 B)                  │
│   magic(4) version(4) write_ptr(4) read_ptr(4)   │
│   total_cap(4) reserved(12) erase_counts[4095×2] │
├─────────────────────────────────────────────────┤
│ Sectors 1…4095  Data (4 095 × 4 096 B)           │
│   Each sector: 227 records × 18 bytes = 4 086 B  │
│   Total capacity: ~929,685 records               │
└─────────────────────────────────────────────────┘
```

Record layout (18 bytes, little-endian):
```
[0..3]  int32  latitude_udeg   (×10⁻⁶ °)
[4..7]  int32  longitude_udeg  (×10⁻⁶ °)
[8..9]  int16  altitude_m
[10..13] uint32 timestamp_s   (Unix epoch)
[14]    uint8  speed_kmh
[15]    uint8  heading_deg/2
[16]    uint8  flags           (GPS_VALID|CHARGING|GEOFENCE)
[17]    uint8  activity_type   (ACT_REST…ACT_SLEEP)
```

---

## Inter-chip UART Protocol

See `UART_PROTOCOL.md` for full packet format and command reference.

---

## OTA Update Flow

```
Phone app initiates DFU
    │
    ▼ (BLE SMP / MCUmgr)
nRF52840 DFU Manager receives image blocks
    │
    ├── nRF52840 image → write to MCUboot slot1
    │   └── reboot → MCUboot swaps → new firmware confirmed
    │
    └── nRF9160 image → relay CMD_DFU_DATA blocks via UART
        └── nRF9160 UART bridge → write to modem FOTA partition
            └── modem apply → nRF9160 reboot
```

---

## Thread Architecture (nRF9160)

| Thread | Stack | Priority | Role |
|--------|-------|----------|------|
| main | 4 096 B | 0 | Init, watchdog feed |
| gps_thread | 2 048 B | 3 | GPS fix processing |
| lte_thread | 2 048 B | 3 | LTE event handling |
| mqtt_thread | 4 096 B | 4 | Cloud publish queue |
| uart_rx_thread | 1 024 B | -2 (coop) | Inter-chip packet receive |
| sys_workq | 2 048 B | -1 | Deferred work items |

---

## Coding Conventions

- Language: C11
- Style: Zephyr coding style (Linux kernel variant)
- Logging: `LOG_MODULE_REGISTER(module_name, LOG_LEVEL_INF)` in every `.c`
- Thread safety: all shared state protected by `k_mutex` or accessed from single thread
- Error handling: every function returns `int` (0 = success, negative = error); errors logged with `LOG_ERR`
- Hardware abstraction: always use Zephyr device tree and driver APIs, never hard-code register addresses except in low-level sensor drivers
