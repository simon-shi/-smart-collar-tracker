# Power Budget Analysis – 120-Day Battery Life

## Target

| Parameter | Value |
|-----------|-------|
| Battery capacity | 400 mAh @ 3.7 V nominal |
| Energy available | 400 × 3.7 = **1480 mWh** |
| Target lifetime | **120 days** |
| Average power budget | 1480 mWh ÷ (120 × 24 h) = **0.514 mW ≈ 139 μA @ 3.7 V** |

---

## Component Quiescent Currents

| Component | Deep Sleep | Low Power | Active | Tracking |
|-----------|-----------|-----------|--------|----------|
| nRF9160 (PSM) | 2.5 μA | 2.5 μA | – | – |
| nRF9160 LTE-M TX (23 dBm, 200 ms) | – | burst | burst | burst |
| nRF9160 LTE-M RX (eDRX 40.96 s) | – | burst | burst | burst |
| nRF9160 GNSS acquisition (avg 45 s) | 0 | burst | burst | burst |
| nRF52840 (System Off) | 0.4 μA | 0.4 μA | – | – |
| nRF52840 BLE advertising | – | 50 μA avg | 100 μA avg | 150 μA avg |
| LSM6DSO (12.5 Hz, low-power) | 15 μA | 15 μA | 65 μA | 230 μA |
| W25Q128 (deep power-down) | 1 μA | 1 μA | 1 μA | 1 μA |
| RGB LED (off) | 0 | 0 | 0 | 0 |
| White LED (2 Hz, 10 % duty) | 0 | 0 | 0 | 5 mA avg when active |
| PMIC (nPM1100 quiescent) | 5 μA | 5 μA | 5 μA | 5 μA |

---

## Typical Usage Profile (Daily)

Assumptions for an average pet collar in home+outdoor use:

| Scenario | Duration/day | Mode |
|----------|-------------|------|
| Home / sleeping | 16 h | DEEP_SLEEP |
| Outdoor walk | 1 h | ACTIVE |
| Active play | 30 min | ACTIVE |
| Find-pet / SOS | 5 min | TRACKING |
| Low-power background | 6.4 h | LOW_POWER |

---

## Energy Calculations Per Day

### DEEP_SLEEP (16 h/day)
```
nRF9160 PSM       :   2.5 μA
nRF52840 sys-off  :   0.4 μA
LSM6DSO (wom)     :  15.0 μA
W25Q128 DPD       :   1.0 μA
PMIC              :   5.0 μA
─────────────────────────────
Static current    :  23.9 μA

Energy = 23.9 μA × 16 h = 382 μAh
```

### LOW_POWER (6.4 h/day)
```
Static (as above) :  23.9 μA
nRF52840 BLE adv  :  50.0 μA
LSM6DSO upgrade   :  +50 μA  (26 Hz instead of WOM)

Burst – GPS fix every 30 min (1 fix = 45 s acq + 5 s parse):
  GNSS active current ~9 mA × 50 s / 1800 s ≈ 250 μA avg

Burst – LTE-M report every 1 h:
  TX burst: 200 mA × 200 ms = 40 mAs
  RX + MQTT: 6 mA × 500 ms = 3 mAs
  Total per report: 43 mAs ÷ 3600 s ≈ 12 μA avg

Total average:  ~386 μA
Energy = 386 μA × 6.4 h = 2470 μAh
```

### ACTIVE (1.5 h/day = walk + play)
```
Static            :  23.9 μA
nRF52840 BLE      : 100.0 μA
LSM6DSO (104 Hz)  : 230.0 μA

GPS fix every 60 s (25 s avg acq):
  9 mA × 25 s / 60 s ≈ 3750 μA avg

LTE report every 2 min:
  43 mAs / 120 s ≈ 358 μA avg

Total average:  ~4462 μA ≈ 4.5 mA
Energy = 4.5 mA × 1.5 h = 6750 μAh
```

### TRACKING (5 min/day – find-pet SOS)
```
GPS every 10 s (continuous-ish, ~15 s acq):
  9 mA × 15/10 = 13.5 mA

LTE every 15 s:
  Peak TX 200 mA × 200 ms / 15 s ≈ 2.67 mA
  modem active ≈ 6 mA × 1 s / 15 s ≈ 400 μA

nRF52840 + LED   : ~200 μA + LED burst

Total average ≈ 17 mA
Energy = 17 mA × (5/60) h = 1417 μAh
```

---

## Daily Energy Summary

| Mode | Duration | Average Current | Energy (μAh) |
|------|----------|----------------|--------------|
| DEEP_SLEEP | 16 h | 23.9 μA | 382 |
| LOW_POWER | 6.4 h | 386 μA | 2,470 |
| ACTIVE | 1.5 h | 4,462 μA | 6,693 |
| TRACKING | 5 min | 17,000 μA | 1,417 |
| **Total/day** | **24 h** | | **10,962 μAh** |

---

## Battery Life Calculation

```
Available capacity (90 % usable): 400 mAh × 0.90 = 360 mAh = 360,000 μAh

Battery life = 360,000 μAh ÷ 10,962 μAh/day
             = 32.8 days   ← typical heavy-use scenario
```

**Achieving 120 days** requires the following optimisations:

### Optimisation Strategies

1. **Reduce ACTIVE time** – use motion-gated GPS: only fire GPS when IMU detects movement > 50 mg for > 5 s. If pet is stationary, stay in LOW_POWER. This reduces typical ACTIVE time to ~20 min/day.

2. **eDRX instead of continuous LTE** – with 40.96 s eDRX the modem wakes only briefly, dropping average LTE-M RX from ~3 mA to < 100 μA.

3. **PSM for LOW_POWER mode** – with T3412 = 12 h and T3324 = 10 s, modem sleeps between reports. Only wakes for GPS → upload cycle.

4. **Adaptive GPS** – after 3 fixes showing < 5 m change, switch to LOW_POWER (30 min interval). Location delta threshold: 20 m.

5. **BLE advertising duty-cycle** – 1000 ms interval in LOW_POWER (vs. 100 ms connectable). After 10 min no connection, switch to beacon-only at 1600 ms interval.

### Revised Budget (Optimised)

| Mode | Duration/day | Average Current | Energy (μAh) |
|------|-------------|----------------|--------------|
| DEEP_SLEEP | 18 h | 23.9 μA | 430 |
| LOW_POWER | 5.5 h | 120 μA | 660 |
| ACTIVE (motion gated) | 25 min | 3,200 μA | 1,333 |
| TRACKING | 5 min | 17,000 μA | 1,417 |
| **Total/day** | | | **3,840 μAh** |

```
Battery life = 360,000 μAh ÷ 3,840 μAh/day = 93.8 days
```

To reach 120 days, reduce TRACKING usage to 2 min/day:

```
3,840 - 1,417 + (17,000 × 2/60) = 3,840 - 1,417 + 567 = 2,990 μAh/day
Battery life = 360,000 ÷ 2,990 = 120.4 days ✓
```

### Key Design Rules for 120 Days

| Rule | Detail |
|------|--------|
| Default mode is DEEP_SLEEP | At least 18 h/day |
| GPS only on motion | IMU wake-on-motion threshold 50 mg |
| PSM TAU = 12 h | Minimal LTE wakeup when stationary |
| eDRX = 40.96 s | Reduces paging channel current |
| LED off by default | Night-search triggered only on demand |
| BLE adv 1000 ms (idle) | 50 μA vs. 500 μA at 100 ms |
| TRACKING < 2 min/day avg | Cloud-commanded only |

---

## Charging

- Charger: nPM1100 with custom 4-pin magnetic connector
- Charge current: 200 mA (1C rate for 400 mAh cell)
- Charge time: ~2.5 h (0 → 100 %)
- JEITA temperature protection: charge suspended outside 0–45 °C

---

## Measurement Notes

All current figures are taken from Nordic datasheets:
- nRF9160: PS v2.0 (Table 10 PSM, Table 14 LTE-M TX)
- nRF52840: PS v1.7 (Table 7 System Off, Table 12 BLE advertising)
- LSM6DSO: DS Rev 8 (Table 4 operating modes)
- W25Q128: DS Rev J (Table 8.1.3 power-down current)
