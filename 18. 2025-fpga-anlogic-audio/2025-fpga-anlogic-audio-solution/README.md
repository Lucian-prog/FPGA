# 🏆 FPGA Audio Processing System - National First Prize Project

[![FPGA Innovation Design Competition](https://img.shields.io/badge/Competition-National%20First%20Prize-gold)](https://fpga.nuedc.cn/)
[![Platform](https://img.shields.io/badge/Platform-Anlogic%20EG4S20-blue)](http://www.anlogic.com/)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

**2025年全国大学生FPGA创新设计竞赛 国家一等奖作品**

本仓库包含基于安路FPGA的完整音频处理系统，涵盖USB音频、声源定位、PDM麦克风、音频均衡器、自动增益控制等多个子项目。

---

## 📋 项目总览

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         FPGA Audio Processing System                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│   ┌─────────────┐   ┌─────────────┐   ┌─────────────┐   ┌─────────────────┐ │
│   │    USB/     │   │  pdm2pcm/   │   │    agc/     │   │ Realtime_Py     │ │
│   │  (主项目)   │   │ (PDM麦克风) │   │ (AGC模块)   │   │  Audio_FFT/     │ │
│   │             │   │             │   │             │   │ (PC端分析)      │ │
│   │ • USB音频   │   │ • PDM解码   │   │ • 自动增益  │   │                 │ │
│   │ • 声源定位  │   │ • CIC滤波   │   │ • 仿真测试  │   │ • 实时FFT       │ │
│   │ • 多模式EQ  │   │ • ES8388    │   │ • DDS信号源 │   │ • 频谱分析      │ │
│   │ • AGC处理   │   │             │   │             │   │                 │ │
│   │ • LED指示   │   │             │   │             │   │                 │ │
│   └─────────────┘   └─────────────┘   └─────────────┘   └─────────────────┘ │
│                                                                               │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 📁 目录结构

```
2025-fpga-anlogic/
│
├── README.md                      # 本文档（项目总览）
│
├── USB/                           # 🎯 主项目：USB音频+声源定位系统
│   ├── README.md                  # USB项目详细文档
│   ├── USB.al                     # Tang Dynasty工程文件
│   ├── src/                       # RTL源代码
│   │   ├── top.v                  # 顶层模块
│   │   ├── xcorr.v                # 互相关声源定位
│   │   ├── mic_led.v              # SK9822 LED驱动
│   │   ├── AUDIO_PROCESS_LITE.v   # 音频处理(IIR+AGC)
│   │   ├── usb_audio_top.v        # USB音频控制器
│   │   └── ...                    # 其他模块
│   ├── al_ip/                     # Anlogic IP核
│   └── sim/                       # 仿真文件
│
├── pdm2pcm/                       # 📢 PDM麦克风转PCM音频系统
│   ├── pdm2pcm.al                 # Tang Dynasty工程文件
│   ├── src/                       # RTL源代码
│   │   ├── PDM_ES8388_System.v    # 顶层模块
│   │   ├── cic_filter.v           # CIC抽取滤波器
│   │   ├── pdm2pcm_lfrg.v         # PDM解码逻辑
│   │   └── ...                    # ES8388/I2S等模块
│   ├── al_ip/                     # Anlogic IP核
│   └── sim/                       # 仿真文件
│
├── agc/                           # 🔊 AGC自动增益控制模块
│   ├── agc.v                      # AGC核心算法
│   ├── agc_tb.v                   # 测试激励
│   └── dds.v                      # DDS信号发生器(测试用)
│
└── Realtime_PyAudio_FFT-master/   # 📊 PC端实时频谱分析工具
    ├── run_FFT_analyzer.py        # 主程序
    ├── requirements.txt           # Python依赖
    └── src/                       # 源代码
```

---

## 🎯 主项目：USB音频+声源定位系统 (`USB/`)

**核心功能：**
- 🎤 **USB音频录音** - UAC 1.0标准，48kHz/16bit立体声，免驱即插即用
- 🔊 **6麦克风声源定位** - 互相关算法，360°全向，30°分辨率
- 🎚️ **多模式音频EQ** - 窄带通话/低音增强/人声增强/氛围感增强
- 🎛️ **AGC自动增益** - 实时动态范围控制
- 🎧 **ES8388本地监听** - 低延迟耳机输出
- 💡 **SK9822 LED指示** - 12颗RGB环形阵列显示声源方向

**工作模式：**
| 模式 | USB录音 | 本地监听 | 声源定位 | LED指示 |
|:---:|:---:|:---:|:---:|:---:|
| 普通模式 (默认) | ✅ | ✅ | ❌ | ❌ |
| 定位模式 | ❌ | ❌ | ✅ | ✅ |

👉 详细文档请查看 [`USB/README.md`](USB/README.md)

---

## 📢 PDM麦克风系统 (`pdm2pcm/`)

**功能特性：**
- PDM数字麦克风接口（支持4路输入）
- CIC抽取滤波器（PDM→PCM转换）
- 48kHz音频采样率输出
- ES8388 DAC本地监听
- 按键控制音频处理模式

**技术参数：**
- PDM时钟：3.072MHz
- CIC滤波器：5阶，抽取比64
- 输出采样率：48kHz
- 数据位宽：16bit

---

## 🔊 AGC模块 (`agc/`)

**独立的自动增益控制模块，可复用于其他项目。**

**算法特点：**
- 双时间常数设计（长期/短期平均）
- 增益限幅保护（防止过调）
- 可配置目标幅度
- 低延迟实时处理

**接口说明：**
```verilog
module agc(
    input clk,                    // 时钟
    input rst_n,                  // 复位
    input signed [23:0] din,      // 24位输入
    input signed [15:0] exp_amp,  // 目标幅度
    output reg signed [15:0] dout // 16位输出
);
```

---

## 📊 PC端频谱分析工具 (`Realtime_PyAudio_FFT-master/`)

**基于Python的实时音频频谱分析器，用于调试和验证FPGA音频系统。**

**功能：**
- 实时FFT频谱显示
- 麦克风/Line-in输入
- 可视化音频波形
- 频率响应分析

**运行方法：**
```bash
cd Realtime_PyAudio_FFT-master
pip install -r requirements.txt
python run_FFT_analyzer.py
```

---

## 🔧 硬件平台

### FPGA芯片
- **型号**: 安路 EG4S20BG256
- **逻辑单元**: ~20K LUTs
- **BRAM**: ~100Kb
- **封装**: BGA256

### 外围器件
| 器件 | 型号 | 用途 |
|:---:|:---:|:---|
| MEMS麦克风 | INMP441 | I2S数字麦克风 (USB项目) |
| PDM麦克风 | SPK0641HT4H | PDM数字麦克风 (pdm2pcm项目) |
| 音频DAC | ES8388 | 本地音频输出 |
| RGB LED | SK9822 | 方向指示 |

### 开发工具
- **FPGA IDE**: 安路 Tang Dynasty 5.6.x+
- **仿真**: Icarus Verilog / ModelSim
- **Python**: 3.8+ (频谱分析工具)

---

## 🚀 快速开始

### 1. 克隆仓库
```bash
git clone https://github.com/Lucian-prog/2025-fpga-anlogic-audio-solution
cd 2025-fpga-anlogic
```

### 2. 选择项目
- **USB音频+声源定位**: 打开 `USB/USB.al`
- **PDM麦克风系统**: 打开 `pdm2pcm/pdm2pcm.al`

### 3. 综合与下载
```
Tang Dynasty IDE:
Flow -> Run All (F5)
Tools -> Download
```

### 4. PC端工具（可选）
```bash
cd Realtime_PyAudio_FFT-master
pip install -r requirements.txt
python run_FFT_analyzer.py
```

---

## 📐 技术亮点

### 1. 互相关声源定位算法
```
基于时延估计的声源定位：
- 采集1024点音频数据
- 计算3对麦克风的互相关
- 寻找相关峰值对应的时延
- 根据时延判断声源方向
```

### 2. 多级IIR滤波器
```
级联二阶IIR节实现各类EQ：
- 窄带通话: 200-4000Hz带通
- 低音增强: 300Hz中心频点
- 人声增强: 2000Hz中心频点
- 氛围感:   4000Hz中心频点
```

### 3. 双时间常数AGC
```
长期平均: 1024采样点 (~21ms @48kHz)
短期平均: 32采样点 (~0.67ms @48kHz)
动态调整增益，快速响应+稳定输出
```

### 4. USB全速设备
```
纯Verilog实现USB 1.1 Full Speed (12Mbps)
无需外部USB PHY芯片
支持UAC 1.0音频类协议
```

---

## 📊 资源使用

### USB项目 (`USB/`)
| 资源 | 使用量 | 占比 |
|:---:|:---:|:---:|
| LUT | ~15,000 | ~75% |
| REG | ~8,000 | ~40% |
| BRAM | ~80Kb | ~80% |
| PLL | 1 | 50% |

### pdm2pcm项目 (`pdm2pcm/`)
| 资源 | 使用量 | 占比 |
|:---:|:---:|:---:|
| LUT | ~5,000 | ~25% |
| REG | ~3,000 | ~15% |
| BRAM | ~20Kb | ~20% |
| PLL | 1 | 50% |

---

## 🤝 贡献

欢迎提交Issue和Pull Request！

---

## 📄 许可证

本项目采用 MIT 许可证

---

## 🙏 致谢

- [sheiyi/2023-fpga-gowin-circuit](https://gitee.com/sheiyi/2023-fpga-gowin-circuit) - 代码骨架和系统设计思路参考，声源定位算法参考
- [WangXuan95/FPGA-USB-Device](https://github.com/WangXuan95/FPGA-USB-Device) - USB核心参考
- [markjay4k/Audio-Spectrum-Analyzer](https://github.com/markjay4k/Audio-Spectrum-Analyzer-in-Python) - FFT分析器参考
- [小梅哥FPGA](https://item.taobao.com/item.htm?id=872098085076) - 板卡来源
- [硬件来源](https://item.taobao.com/item.htm?id=591820993474) - 麦克风阵列/扩展板
- [安路科技](http://www.anlogic.com/) - FPGA平台支持
- 全国大学生FPGA创新设计竞赛组委会
---

<p align="center">
  <b>🏆 2025年全国大学生FPGA创新设计竞赛 国家一等奖 🏆</b>
</p>

<p align="center">
  <i>Created with ❤️ for FPGA Innovation</i>
</p>
