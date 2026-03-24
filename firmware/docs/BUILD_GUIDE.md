# Build & Flash Guide

## Prerequisites

### Host Tools

| Tool | Minimum Version | Install |
|------|----------------|---------|
| nRF Connect SDK | 2.7.0 | [nRF Connect for Desktop](https://www.nordicsemi.com/Products/Development-tools/nRF-Connect-for-Desktop) |
| Zephyr RTOS | bundled with NCS | via west |
| west | 1.2.0 | `pip install west` |
| CMake | 3.20.0 | system package manager |
| Python | 3.10+ | system package manager |
| nrfjprog | 10.24+ | [nRF Command Line Tools](https://www.nordicsemi.com/Products/Development-tools/nRF-Command-Line-Tools) |
| J-Link | 7.80+ | bundled with nrfjprog |
| arm-zephyr-eabi GCC | 12.2 | bundled with NCS toolchain |

### One-Time Setup

```bash
# Install west
pip install west

# Initialise nRF Connect SDK workspace (run once)
west init -m https://github.com/nrfconnect/sdk-nrf --mr v2.7.0 ~/ncs
cd ~/ncs
west update
west zephyr-export

# Install Python dependencies
pip install -r zephyr/scripts/requirements.txt
pip install -r nrf/scripts/requirements.txt
```

---

## Repository Layout

```
firmware/
├── nrf9160/      ← Build directory for cellular/GNSS firmware
├── nrf52840/     ← Build directory for BLE firmware
├── common/       ← Shared headers and sources (included by both)
├── docs/         ← Documentation
└── scripts/
    ├── build.sh  ← Build both firmwares
    └── flash.sh  ← Flash both chips
```

---

## Building

### Quick Build (both chips)

```bash
cd firmware
./scripts/build.sh
```

Built binaries are placed in:
- `build/nrf9160/zephyr/app_signed.hex` (MCUboot-signed nRF9160 image)
- `build/nrf52840/zephyr/app_signed.hex` (MCUboot-signed nRF52840 image)

### Manual Build – nRF9160

```bash
cd firmware/nrf9160
west build -b smart_collar_nrf9160 \
     -p always \
     --build-dir ../../build/nrf9160 \
     -- \
     -DBOARD_ROOT=$(pwd)/.. \
     -DCONF_FILE=prj.conf \
     -DDTC_OVERLAY_FILE=boards/smart_collar_nrf9160.overlay
```

### Manual Build – nRF52840

```bash
cd firmware/nrf52840
west build -b smart_collar_nrf52840 \
     -p always \
     --build-dir ../../build/nrf52840 \
     -- \
     -DBOARD_ROOT=$(pwd)/.. \
     -DCONF_FILE=prj.conf \
     -DDTC_OVERLAY_FILE=boards/smart_collar_nrf52840.overlay
```

### Build with Custom MQTT Endpoint

```bash
west build ... -- -DMQTT_BROKER_ENDPOINT='"your-endpoint.iot.us-east-1.amazonaws.com"'
```

### Debug Build (RTT logging)

```bash
west build ... -- -DCONFIG_LOG_BACKEND_RTT=y -DCONFIG_LOG_BACKEND_UART=n \
                  -DCONFIG_DEBUG_OPTIMIZATIONS=y
```

---

## Flashing

### Quick Flash (both chips, requires J-Link connected)

```bash
cd firmware
./scripts/flash.sh
```

### Flash nRF9160

```bash
# Erase and flash (includes MCUboot)
nrfjprog --recover --coprocessor CP_Application
nrfjprog --program build/nrf9160/zephyr/merged.hex \
         --sectorerase --coprocessor CP_Application
nrfjprog --reset
```

Or using west:
```bash
west flash --build-dir build/nrf9160 --runner nrfjprog
```

### Flash nRF52840

```bash
nrfjprog --recover
nrfjprog --program build/nrf52840/zephyr/merged.hex --sectorerase
nrfjprog --reset
```

Or using west:
```bash
west flash --build-dir build/nrf52840 --runner nrfjprog
```

### Flash nRF9160 Modem Firmware

The cellular modem firmware is separate from the application:

```bash
# Download modem firmware from Nordic (e.g. mfw_nrf9160_1.3.6.zip)
nrfjprog --program mfw_nrf9160_1.3.6.zip --coprocessor CP_MODEM
nrfjprog --reset
```

---

## Provisioning

### AWS IoT Core Certificates

The device authenticates to AWS IoT Core using mutual TLS (client certificate + private key).

1. Create a Thing in AWS IoT Core and download:
   - `device-certificate.pem.crt`
   - `private.pem.key`
   - `AmazonRootCA1.pem`

2. Convert to DER and embed in firmware:
```bash
# Convert PEM to DER
openssl x509 -in device-certificate.pem.crt -out device-cert.der -outform DER
openssl rsa  -in private.pem.key            -out device-key.der  -outform DER
openssl x509 -in AmazonRootCA1.pem          -out ca-cert.der     -outform DER
```

3. Flash credentials to nRF9160 security storage using `nrfcredstore`:
```bash
nrfcredstore /dev/ttyACM0 write 16842753 CLIENT_CERT device-cert.der
nrfcredstore /dev/ttyACM0 write 16842753 CLIENT_KEY  device-key.der
nrfcredstore /dev/ttyACM0 write 16842753 ROOT_CA     ca-cert.der
```

### Device ID

The device uses the nRF9160 hardware UUID as its unique device identifier. Retrieve it:
```bash
# Connect to nRF9160 UART console
minicom -D /dev/ttyACM0 -b 115200
# Issue AT command
AT+CGSN=1
```

---

## OTA Firmware Update (BLE)

### Using nRF Connect for Mobile

1. Build the new firmware with `west build`
2. Locate `build/nrf52840/zephyr/app_update.bin`
3. Open **nRF Connect** app on iOS/Android
4. Connect to "PetCollar-XXXX"
5. Navigate to **DFU** → select `app_update.bin`
6. Confirm upload; device reboots automatically

### Updating nRF9160 via BLE

1. Build nRF9160 firmware
2. Locate `build/nrf9160/zephyr/app_update.bin`
3. Use same nRF Connect DFU flow but select the nRF9160 image
4. The nRF52840 relays the image to nRF9160 via UART (CMD_DFU_DATA)

---

## Serial Console / Logging

### nRF9160 UART console

```bash
# 115200 bps, 8N1
minicom -D /dev/ttyACM0 -b 115200
# or
screen /dev/ttyACM0 115200
```

### nRF52840 UART console

```bash
minicom -D /dev/ttyACM1 -b 115200
```

### RTT (Segger J-Link Real-Time Transfer)

```bash
JLinkRTTClient
# Then: open terminal 0
```

---

## Board File (Custom PCB)

If using the custom Smart Collar PCB, add the board definition:

```bash
export BOARD_ROOT=/path/to/firmware
west build -b smart_collar_nrf9160 ...
```

For development on a Nordic DK (nRF9160-DK + nRF52840-DK), use:
```bash
# nRF9160
west build -b nrf9160dk_nrf9160_ns ...

# nRF52840
west build -b nrf52840dk_nrf52840 ...
```

---

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| `GNSS: init failed` | Modem firmware not updated | Flash mfw_nrf9160_1.3.6+ |
| `LTE: registration timeout` | SIM not provisioned | Check APN settings, CONFIG_LTE_NETWORK_MODE |
| `MQTT: TLS handshake failed` | Certificate mismatch | Re-provision certificates with correct security tag |
| `BLE: bt_enable failed` | Controller not initialised | Check CONFIG_BT_CTLR=y in prj.conf |
| `Flash: QSPI device not ready` | DT overlay mismatch | Verify QSPI pin assignments in overlay |
| `CRC mismatch on UART bridge` | Baud rate mismatch | Verify both sides use UART_BAUD_RATE=1000000 |
| Build error: `west not found` | PATH not set | `source ~/ncs/zephyr/zephyr-env.sh` |

---

## Regulatory Notes

| Region | Standard | Config |
|--------|---------|--------|
| US | FCC Part 15B, FCC Part 22/24 | `CONFIG_LTE_BAND_MASK` for US LTE bands |
| Canada | ISED RSS-247 | Same as US bands |
| EU | CE RED Directive, ETSI EN 303 413 | Add EU LTE bands (B3, B7, B20, B28) |
| UK | UKCA, Ofcom | Same as EU + B28 |

Set `CONFIG_LTE_BAND_LOCK` to restrict to certified bands for the target market.
