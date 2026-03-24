# Smart Pet Collar Tracker

基于 nRF9160 + nRF52840 的宠物智能定位项圈固件 / Smart Pet Collar Tracker Firmware based on nRF9160 + nRF52840.

---

## 产品概述 / Product Overview

| 参数 | 规格 |
|------|------|
| 重量 | ≤ 30 g |
| 续航 | ≥ 120 天 (400 mAh LiPo) |
| 防水 | IP68（支持游泳佩戴）|
| 天线 | LDS 激光直接成型工艺 |
| LED | RGB + 白色大功率（夜间寻宠）|
| 离线存储 | W25Q128 NOR Flash 16MB（约 93 万条轨迹点）|
| 充电 | 定制磁吸 4-Pin 接口（充电 + 数据传输）|
| 目标市场 | 美国、加拿大、欧盟、英国 |

---

## 硬件架构 / Hardware Architecture

```
┌─────────────────────────────────────────────────┐
│                Smart Pet Collar                   │
│                                                   │
│  ┌──────────────┐  UART 1Mbps  ┌──────────────┐  │
│  │  nRF9160     │◄────────────►│  nRF52840    │  │
│  │  Cellular    │              │  BLE 5.0     │  │
│  │  + GNSS      │              │  + Sensor    │  │
│  └──────┬───────┘              └──────┬───────┘  │
│         │ I2C                         │ QSPI      │
│         ▼                             ▼           │
│  ┌──────────────┐              ┌──────────────┐  │
│  │  LSM6DSO     │              │  W25Q128     │  │
│  │  6-axis IMU  │              │  16MB Flash  │  │
│  └──────────────┘              └──────────────┘  │
│                                                   │
│  ┌──────────────┐  ┌──────────────────────────┐  │
│  │  nPM1100     │  │  RGB + White LED (PWM)   │  │
│  │  PMIC        │  └──────────────────────────┘  │
│  └──────────────┘                                 │
└─────────────────────────────────────────────────┘
         │                        │
    LTE-M/NB-IoT               BLE 5.0
         │                        │
    AWS IoT Core              Phone App
    (MQTT/TLS)                (iOS/Android)
```

---

## 功能特性 / Features

- **GPS 定位追踪**: nRF9160 GNSS，支持 A-GPS 快速定位，可配置追踪间隔（10s / 60s / 30min）
- **虚拟栅栏**: 圆形 + 多边形地理围栏（最多 10 个），越界即时告警
- **宠物活动识别**: LSM6DSO + 机器学习核，识别静止/行走/奔跑/玩耍/游泳/睡眠
- **健康数据**: 步数统计、卡路里估算、异常行为检测
- **离线轨迹**: 断网时自动写入 NOR Flash，恢复联网后上传云端
- **超长续航**: 120 天 @ 400 mAh，4 级电源管理状态机
- **OTA 升级**: BLE SMP（MCUmgr），支持两颗芯片无线升级
- **夜间寻宠**: 白色 LED 2Hz 闪烁，云端远程触发
- **iBeacon**: 未配对时广播 iBeacon，支持众包寻宠

---

## 固件结构 / Firmware Structure

```
firmware/
├── nrf9160/                    # 蜂窝 + GNSS 固件
│   ├── src/
│   │   ├── gps/                # GNSS 控制器 + 离线轨迹
│   │   ├── lte/                # LTE-M/NB-IoT 管理
│   │   ├── cloud/              # MQTT/TLS → AWS IoT Core
│   │   ├── sensors/            # LSM6DSO 驱动 + 活动分类
│   │   ├── geofence/           # 地理围栏引擎
│   │   ├── power/              # 电源状态机
│   │   ├── led/                # LED 控制器
│   │   └── uart_bridge/        # 芯片间通信
│   ├── CMakeLists.txt
│   ├── Kconfig
│   └── prj.conf
│
├── nrf52840/                   # BLE 固件
│   ├── src/
│   │   ├── ble/                # BLE 栈 + GATT 服务 + iBeacon
│   │   ├── dfu/                # OTA 升级管理
│   │   ├── flash/              # W25Q128 环形缓冲区
│   │   ├── charge/             # 磁吸充电检测
│   │   └── uart_bridge/        # 芯片间通信
│   ├── CMakeLists.txt
│   ├── Kconfig
│   └── prj.conf
│
├── common/                     # 两颗芯片共享
│   ├── include/
│   │   ├── protocol.h          # 芯片间 UART 协议
│   │   ├── pet_data.h          # 共享数据结构
│   │   └── config.h            # 全局配置常量
│   └── src/
│       ├── protocol.c          # CRC16-CCITT + 编解码
│       └── pet_data.c          # 序列化帮助函数
│
├── docs/
│   ├── FIRMWARE_ARCHITECTURE.md
│   ├── POWER_BUDGET.md
│   ├── BLE_PROTOCOL.md
│   ├── UART_PROTOCOL.md
│   └── BUILD_GUIDE.md
│
└── scripts/
    ├── build.sh                # 编译两颗芯片
    └── flash.sh                # 烧录两颗芯片
```

---

## 快速开始 / Quick Start

### 环境要求

- nRF Connect SDK v2.7+
- west ≥ 1.2.0
- nrfjprog ≥ 10.24

### 编译

```bash
cd firmware
./scripts/build.sh
```

### 烧录

```bash
./scripts/flash.sh
```

详见 [docs/BUILD_GUIDE.md](firmware/docs/BUILD_GUIDE.md)

---

## 电源预算 / Power Budget

| 状态 | GPS 间隔 | LTE 间隔 | 平均电流 |
|------|---------|---------|---------|
| DEEP_SLEEP | 关闭 | 12 h PSM | ~24 μA |
| LOW_POWER | 30 min | 1 h | ~120 μA |
| ACTIVE | 60 s | 2 min | ~3.2 mA |
| TRACKING | 10 s | 15 s | ~17 mA |

典型使用场景下（每天 18h 深度睡眠 + 25min 活动 + 2min 追踪）可达 **120 天续航**。

详见 [docs/POWER_BUDGET.md](firmware/docs/POWER_BUDGET.md)

---

## BLE 服务 / BLE Services

| 服务 | UUID | 说明 |
|------|------|------|
| Device Information | 0x180A | 厂商/型号/版本信息 |
| Battery Service | 0x180F | 电量通知 |
| Pet Tracker Service | 128-bit (custom) | 位置/活动/围栏/控制 |
| MCUmgr SMP | 128-bit | OTA 升级 |

详见 [docs/BLE_PROTOCOL.md](firmware/docs/BLE_PROTOCOL.md)

---

## 芯片间协议 / Inter-chip Protocol

```
| SOF(0xAA) | Length(2B LE) | Cmd(1B) | SeqNo(1B) | Payload(0-512B) | CRC16-CCITT(2B) |
```

14 条命令覆盖 GPS、活动、围栏、LED、DFU、电源模式等所有场景。

详见 [docs/UART_PROTOCOL.md](firmware/docs/UART_PROTOCOL.md)

---

## 合规认证 / Regulatory Compliance

| 地区 | 认证 |
|------|------|
| 美国 | FCC Part 15B, Part 22/24 |
| 加拿大 | ISED RSS-247 |
| 欧盟 | CE RED Directive, ETSI EN 303 413 |
| 英国 | UKCA |

---

## 许可证 / License

Apache-2.0 – see [LICENSE](LICENSE)
