# 🏆 FPGA-Based USB Audio System with Sound Source Localization

[![FPGA Innovation Design Competition](https://img.shields.io/badge/Competition-National%20First%20Prize-gold)](https://fpga.nuedc.cn/)
[![Platform](https://img.shields.io/badge/Platform-Anlogic%20EG4S20-blue)](http://www.anlogic.com/)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

**2025年全国大学生FPGA创新设计竞赛 国家一等奖作品**

基于安路FPGA的USB音频系统，集成6麦克风阵列声源定位、多模式音频均衡器(EQ)、自动增益控制(AGC)等功能。

---

## 📋 目录

- [项目简介](#项目简介)
- [系统架构](#系统架构)
- [功能特性](#功能特性)
- [硬件需求](#硬件需求)
- [文件结构](#文件结构)
- [快速开始](#快速开始)
- [工作模式](#工作模式)
- [技术细节](#技术细节)
- [引脚分配](#引脚分配)
- [常见问题](#常见问题)
- [贡献指南](#贡献指南)
- [许可证](#许可证)
- [致谢](#致谢)

---

## 📖 项目简介

本项目是一个基于**安路EG4S20BG256 FPGA**的多功能USB音频处理系统，主要实现：

1. **USB音频设备** - 兼容USB Audio Class 1.0，48kHz/16bit立体声
2. **6麦克风阵列声源定位** - 基于互相关算法的实时360°声源方向检测
3. **多模式音频均衡器** - 包含窄带通话、低音增强、人声增强、氛围感增强等EQ模式
4. **自动增益控制(AGC)** - 实时动态范围压缩，保证输出电平稳定
5. **本地音频监听** - 通过ES8388 DAC实现低延迟耳机监听
6. **SK9822 LED指示** - 12颗RGB LED环形阵列实时显示声源方向

---

## 🏗️ 系统架构

```
                                    ┌─────────────────────────────────────────────────────┐
                                    │                   FPGA Top Module                     │
                                    │                                                       │
    ┌──────────┐                    │  ┌─────────────┐    ┌─────────────┐                  │
    │ 6-Mic    │──── I2S ──────────>│  │ mic_serial  │───>│   xcorr     │──┐              │
    │ Array    │                    │  │ (I2S Rx)    │    │  (x3)       │  │              │
    └──────────┘                    │  └─────────────┘    └─────────────┘  │              │
                                    │         │                             │              │
                                    │         │          ┌─────────────┐   │              │
                                    │         v          │  mic_led    │<──┘              │
    ┌──────────┐                    │  ┌─────────────┐   │ (SK9822)    │                  │
    │ DIP      │──── GPIO ─────────>│  │AUDIO_PROCESS│   └──────┬──────┘                  │
    │ Switch   │                    │  │ (IIR+AGC)   │          │                         │
    └──────────┘                    │  └──────┬──────┘          v                         │
                                    │         │          ┌──────────────┐                 │
                                    │         │          │ 12x SK9822   │                 │
    ┌──────────┐                    │         v          │  LED Ring    │                 │
    │ USB      │<─── USB 1.1 ──────>│  ┌─────────────┐   └──────────────┘                 │
    │ Host     │                    │  │usb_audio_top│                                    │
    └──────────┘                    │  │(Full Speed) │                                    │
                                    │  └─────────────┘                                    │
                                    │         │                                            │
    ┌──────────┐                    │         v                                            │
    │ ES8388   │<─── I2S/I2C ──────>│  ┌─────────────┐                                    │
    │ DAC      │                    │  │ ES8388_Init │                                    │
    └──────────┘                    │  │  + i2s_tx   │                                    │
                                    │  └─────────────┘                                    │
                                    └─────────────────────────────────────────────────────┘
```

---

## ✨ 功能特性

### 🎤 USB音频录音
- USB Full Speed (12Mbps) 兼容
- USB Audio Class 1.0 (UAC 1.0) 标准
- 48kHz 采样率，16bit 分辨率
- 双声道立体声录音
- 免驱动，即插即用 (Windows/Linux/macOS)

### 🔊 声源定位
- 6麦克风环形阵列
- 基于互相关(Cross-Correlation)算法
- 360°全向定位，30°分辨率
- 实时LED方向指示
- 滞后滤波防抖动

### 🎚️ 音频均衡器 (EQ)
| 开关 | 功能 | 中心频点 | 说明 |
|:---:|:---:|:---:|:---|
| SW0 | AGC开关 | - | 自动增益控制使能 |
| SW1 | 窄带通话 | 200-4000Hz | 电信级通话质量 |
| SW2 | 低音增强 | 300Hz | 增强低频厚度 |
| SW3 | 人声增强 | 2000Hz | 提升人声清晰度 |
| SW4 | 氛围感 | 4000Hz | 增强空间感和细节 |
| SW5 | 窄带备用 | 200-4000Hz | 与SW1相同，低优先级 |

### 🎧 本地监听
- ES8388 高品质DAC
- I2S接口，48kHz/32bit
- 低延迟实时监听
- 独立音频输出

### 💡 LED指示
- SK9822 RGB LED (12颗环形阵列)
- SPI协议驱动
- 实时声源方向显示
- 方向累积计数防抖

---

## 🔧 硬件需求

### FPGA平台
- **芯片**: 安路 EG4S20BG256
- **逻辑单元**: ~20K LUTs
- **BRAM**: ~100Kb
- **时钟**: 50MHz 板载晶振

### 外围器件
| 器件 | 型号 | 数量 | 用途 |
|:---:|:---:|:---:|:---|
| MEMS麦克风 | INMP441/SPH0645 | 6 | I2S数字麦克风阵列 |
| 音频DAC | ES8388 | 1 | 本地音频输出 |
| RGB LED | SK9822 | 12 | 方向指示灯环 |
| USB接口 | Type-C | 1 | USB音频连接 |

### 开发工具
- **IDE**: 安路 Tang Dynasty (TD) 5.6.x+
- **仿真**: Icarus Verilog / ModelSim
- **波形**: GTKWave

---

## 📁 文件结构

```
USB/
├── README.md                 # 本文档
├── USB.al                    # Tang Dynasty工程文件
├── IO.adc                    # 引脚约束文件
│
├── src/                      # RTL源代码
│   ├── top.v                 # 顶层模块
│   │
│   ├── # === 麦克风采集 ===
│   ├── mic_serial.v          # 6路I2S麦克风数据接收
│   ├── i2s_receive.v         # I2S接收器
│   │
│   ├── # === 声源定位 ===
│   ├── xcorr.v               # 互相关计算模块
│   ├── mic_led.v             # SK9822 LED驱动+方向判断
│   │
│   ├── # === 音频处理 ===
│   ├── AUDIO_PROCESS_LITE.v  # 音频处理主模块
│   ├── iir.v                 # IIR低通/高通滤波器
│   ├── iir_ch.v              # IIR带通滤波器
│   ├── agc.v                 # 自动增益控制
│   │
│   ├── # === USB音频 ===
│   ├── usb_audio_top.v       # USB音频控制器顶层
│   ├── usbfs_core_top.v      # USB Full Speed核心
│   ├── usbfs_bitlevel.v      # USB位级处理
│   ├── usbfs_packet_rx.v     # USB包接收
│   ├── usbfs_packet_tx.v     # USB包发送
│   ├── usbfs_transaction.v   # USB事务层
│   │
│   ├── # === ES8388 DAC ===
│   ├── ES8388_Init.v         # ES8388 I2C初始化
│   ├── ES8388_init_table.v   # I2C寄存器配置表
│   ├── i2s_tx.v              # I2S发送器
│   ├── i2c_*.v               # I2C控制器
│   │
│   ├── # === 基础模块 ===
│   ├── clkdiv.v              # 时钟分频器
│   ├── dpram.v               # 双端口RAM
│   └── async_fifo*.v         # 异步FIFO
│
├── al_ip/                    # Anlogic IP核
│   ├── pll.v                 # PLL时钟生成
│   └── BRAM.v                # Block RAM
│
├── sim/                      # 仿真文件
│   ├── mic_tb.v              # 顶层仿真测试
│   └── run_sim.ps1           # 仿真运行脚本
│
└── USB_Runs/                 # 综合布局布线输出
    ├── syn_1/                # 综合结果
    └── phy_1/                # 布局布线结果
```

---

## 🚀 快速开始

### 1. 克隆仓库
```bash
git clone https://github.com/yourusername/fpga-usb-audio-ssl.git
cd fpga-usb-audio-ssl/USB
```

### 2. 打开工程
使用安路 Tang Dynasty IDE 打开 `USB.al` 工程文件。

### 3. 综合与实现
```
Flow -> Run All (F5)
```

### 4. 下载到FPGA
```
Tools -> Download
```

### 5. 连接USB
将FPGA板USB接口连接至PC，系统将识别为USB音频设备。

---

## 🎮 工作模式

系统支持两种互斥的工作模式，通过`mode_switch`按钮切换：

### 普通模式 (mode=0, 默认)
- ✅ USB音频录音正常工作
- ✅ ES8388本地监听正常
- ✅ 音频EQ处理有效
- ❌ 声源定位关闭
- ❌ LED指示关闭

### 声源定位模式 (mode=1)
- ❌ USB音频录音暂停
- ❌ ES8388本地监听暂停
- ✅ 互相关计算工作
- ✅ LED实时显示声源方向

---

## 📐 技术细节

### 时钟树
```
clk50mhz (50MHz 板载晶振)
    │
    ├── PLL ──> clk60mhz (60MHz, USB/DSP)
    │
    ├── PLL ──> I2S_MCLK (12.288MHz, ES8388)
    │               │
    │               ├── ÷4 ──> I2S_BCLK (3.072MHz)
    │               │
    │               └── ÷256 ──> I2S_LRCLK (48kHz)
    │
    └── ÷50 ──> clk_slow (1MHz, LED驱动)
```

### 采样率计算
- 音频采样率: 48kHz
- USB时钟: 60MHz
- 每采样周期: 60MHz ÷ 48kHz = 1250 cycles

### 互相关算法
```
             1023
xcorr(τ) = Σ mic1[n] × mic2[n+τ]
            n=0

τ ∈ [-30, +30]  (共61个偏移量)
```

### IIR滤波器结构
采用Direct Form II Transposed结构，二阶Butterworth设计：
```
y[n] = k3/1024 × (x[n] + 2×x[n-1] + x[n-2]) 
     + k1/1024 × y[n-1] - k2/1024 × y[n-2]
```

---

## 📍 引脚分配

主要引脚分配（详见`IO.adc`文件）：

| 信号 | 引脚 | 方向 | 说明 |
|:---:|:---:|:---:|:---|
| clk50mhz | R7 | Input | 50MHz晶振 |
| rst_n | - | Input | 复位按钮 |
| mode_switch | - | Input | 模式切换 |
| mic_clk | - | Output | 麦克风时钟 |
| mic_ws | - | Output | 麦克风帧同步 |
| mic_data[3:0] | - | Input | 麦克风数据 |
| usb_dp | - | Inout | USB D+ |
| usb_dn | - | Inout | USB D- |
| sk9822_clk | - | Output | LED时钟 |
| sk9822_data | - | Output | LED数据 |

---

## ❓ 常见问题

### Q: USB设备无法识别？
A: 检查以下几点：
1. 确认`usb_dp_pull`上拉电阻已连接 (1.5kΩ)
2. 检查USB线缆是否支持数据传输
3. 确认FPGA程序已正确下载

### Q: 声源定位不准确？
A: 可能原因：
1. 麦克风阵列几何尺寸不正确
2. 某路麦克风损坏或接触不良
3. 环境噪声过大

### Q: 音频有噪声？
A: 尝试以下方法：
1. 开启AGC功能 (SW0=1)
2. 选择合适的EQ模式
3. 检查接地和电源滤波

---

## 🤝 贡献指南

欢迎提交Issue和Pull Request！

1. Fork本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 创建Pull Request

---

## 📄 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件

---

## 🙏 致谢

- [sheiyi/2023-fpga-gowin-circuit](https://gitee.com/sheiyi/2023-fpga-gowin-circuit) - 代码骨架和系统设计思路参考，声源定位算法参考
- [WangXuan95/FPGA-USB-Device](https://github.com/WangXuan95/FPGA-USB-Device) - USB核心参考
- [安路科技](http://www.anlogic.com/) - FPGA平台支持
- 全国大学生FPGA创新设计竞赛组委会

---

## 📞 联系方式

如有问题，请通过以下方式联系：

- 📧 Email: 2512640924@qq.com
- 💬 Issues: [GitHub Issues](https://github.com/yourusername/fpga-usb-audio-ssl/issues)

---

<p align="center">
  <b>🏆 2025年全国大学生FPGA创新设计竞赛 国家一等奖 🏆</b>
</p>
