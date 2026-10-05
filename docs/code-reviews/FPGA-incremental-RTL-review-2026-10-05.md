# FPGA 增量 RTL 静态审查：完整帧与 50 MHz 音频流水线（2026-10-05）

## 结论

本轮覆盖 **1 个新增源码提交、9 个变更文件（5 个 RTL、4 个仿真资产）**。完整帧捕获、50 MHz 逐样本控制、IIR/AGC 分拍计算及 DAC 每结果写一次的核心方向合理。按当前固定参数与接口逐拍推导，**未发现新增计算流水线的确定数值回归或正常帧间隔下的握手丢样**；这不是动态验证通过或系统签核。

发现 **1 项新接口的确定边界缺陷**：特定低电平 BCLK 复位相位下，首个 frame_valid 仍可标记未收齐的帧。需要优先继续处理的输出侧问题是：DAC 写入与播放速率仍不一致，FIFO 满时结果直接丢弃；USB 仍直接采样另一个时钟域的多位结果，没有整帧传递协议。另有保留的 AGC 负满量程幅度误判，以及新增首帧测试的激励盲区。前述既有问题与新增验证缺口分别标记，不把它们全部归因于本次重构。

**方法与限制：仅通过 GitHub 读取固定 SHA 的源码、差异和文档，进行离线静态审查。没有编译、lint、仿真、综合、形式验证、CDC/RDC 工具检查、布局布线、STA 或上板测试。** 作者提交说明里的 Icarus、Verilator、Yosys 与展开结果均未复现、未独立验证。下面的周期、频率和数值是源码推导，不是实测结果。

## 一、版本与范围

- 仓库：[Lucian-prog/FPGA](https://github.com/Lucian-prog/FPGA)，默认分支 `main`。本轮分支查询分页完成，只发现 `main`。
- 已审源 SHA：[`b611af4b8bb945684ba8c0e86720dadaa4f3ea3a`](https://github.com/Lucian-prog/FPGA/commit/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a)，提交时间为 2026-10-04 14:11:32 UTC。
- 上一源基线：[`8895c004848271d7708644ce6f58f05dc68c63dc`](https://github.com/Lucian-prog/FPGA/commit/8895c004848271d7708644ce6f58f05dc68c63dc)。
- 父链：`8895c00（已审源码）→ 4954cfe（仅上一份报告）→ b611af4（本轮源码）`。源基线比较为 ahead=2、behind=0；从报告提交 `4954cfe13f99b3a4c9959aaef79efdc7a1812953` 比较则为 ahead=1、behind=0，恰好 9 个源码/仿真资产变化。上一份报告自身不算新的代码输入。
- 已核对 [上一份增量报告](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/docs/code-reviews/FPGA-incremental-RTL-review-2026-10-04.md) 的检查点和范围；此前 Bagu 全量报告已存在，本轮不重复。
- 完整递归树有 474 个条目，`truncated=false`。已读根 [AGENTS.md](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/AGENTS.md)、内层项目 README 及 [README.md](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/README.md)；音频目录及报告目录没有更深层适用的 AGENTS.md。根说明所指外层音频目录没有独立 README，以实际内层项目为准。
- 下文短路径相对于 `18. 2025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/`，所有源码链接固定到已审源 SHA。
- 仅新增本报告；不修改 RTL、TB、约束、工程文件或已有报告。只有 `docs/code-reviews/` 报告变化的提交应被后续检查跳过，不用报告提交替代源检查点。

### 变更覆盖表

| 文件 | 差异 | 已检查内容 |
|---|---:|---|
| [src/mic_serial.v](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/mic_serial.v) | +69/-2 | 全文；控制同步、下降沿捕获、帧边界资格、左右配对、复位隔离和旧输出路径 |
| [src/AUDIO_PROCESS_LITE.v](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/AUDIO_PROCESS_LITE.v) | +174/-120 | 全文；14 路滤波实例、模式/数据锁存、valid/ready、统一输出与样本代际 |
| [src/iir.v](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/iir.v) | +96/-1 | 全文；旧模块及新增逐样本模块，41/57 与 42/42 位配置、乘除/截断、状态提交 |
| [src/agc.v](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/agc.v) | +107/-1 | 全文；旧/新算法、乘法流水、反馈计数、增益与极值 |
| [src/top.v](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/top.v) | +24/-37 | 全文；本次新端口、50 MHz 连线、输入 overrun、USB 消费及 DAC 写入条件 |
| [sim/audio_process_reference.v](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/sim/audio_process_reference.v) | 新增 221 行 | 全文；旧连接参考与 DSP 行为替身是否匹配旧配置 |
| [sim/audio_process_tb.sv](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/sim/audio_process_tb.sv) | 新增 178 行 | 全文；记账、数值参考、所有开关组合、背压输入、延迟与复位中止 |
| [sim/i2s_receive_tb.sv](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/sim/i2s_receive_tb.sv) | +58/-2 | 全文；首个完整帧、连续编号、旁路集成和旧七路检查的边界 |
| [sim/run_audio_process.ps1](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/sim/run_audio_process.ps1) | 新增 33 行 | 全文；明确顶层、文件清单、退出码、零/Z 两种尾部模式；没有执行 |

补充上下文：
- 全文阅读 [src/i2s_receive.v](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/i2s_receive.v)、[src/clkdiv.v](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/clkdiv.v)、[src/iir_ch.v](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/iir_ch.v)、[src/i2s_tx.v](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/i2s_tx.v)、[src/async_fifo.v](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/async_fifo.v)、[src/async_fifo_ctrl.v](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/async_fifo_ctrl.v)、[src/dpram.v](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/dpram.v)；用于输入事件、旧数值语义、DAC 消费节拍和 FIFO 深度。
- 阅读 [src/usb_audio_top.v:L1–L73](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/usb_audio_top.v#L1-L73)、[src/usb_audio_top.v:L137–L196](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/usb_audio_top.v#L137-L196) 及 201–285 行的接口/描述符上下文；仅评价样本入口和节拍，不签核 USB 协议内核。
- 读取 [src/mic_data_store.v](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/mic_data_store.v)、[src/xcorr.v](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/xcorr.v) 的采样与实例关系，复核上一轮问题是否仍在；不新增互相关算法全量审查。
- 全文检查 [USB.al](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/USB.al)、[IO.adc](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/IO.adc)、[al_ip/pll.v](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/al_ip/pll.v)、[al_ip/pll.ipc](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/al_ip/pll.ipc)；核对工程源入口、频率声明与约束边界。新增 step 模块在原有 iir/agc 源文件中，工程清单已包含这些文件。
- 对上一源基线的 AUDIO_PROCESS、iir、iir_ch、agc 及 DSP.v/DSP.ipc 配置做数值语义交叉核对；未运行厂商原语。

新增/修改文件覆盖为 **9/9**。以上依赖的阅读不等于全仓、完整 USB、完整定位或整板签核。

### 分级与来源

- **P1 高**：损坏连续样本流，或存在关键整字跨域风险。
- **P2 中**：数值边界、物理实现前提或明显验证缺口。
- **确定缺陷/行为**：给定触发条件可以从 RTL 推出；**条件风险**：还取决于时序、契约或实现，不声称硬件已失败。
- **既有/保留**：基线已存在，本次未修复；**本次新增验证缺口**：检查不充分，不等于已经发现 DUT 回归。
- 固定 24 位输入、取高 16 位、7 路映射、原递推的旧样本关系均可作为教学/兼容契约；不因它们不是通用 IP 就报错。

## 二、明确的功能与数值问题

### F01 · P2 · BCLK 低电平期间复位，首个 frame_valid 可仍是无效启动帧

**来源：本次新“完整帧有效”接口的确定边界缺陷；由新资格逻辑与既有分频器复位弱点相互作用引发。**

- 新逻辑位置：[src/mic_serial.v:L71–L124](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/mic_serial.v#L71-L124)，尤其115–124行；依赖位置：[src/clkdiv.v:L24–L59](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/clkdiv.v#L24-L59)、[src/i2s_receive.v:L51–L70](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/i2s_receive.v#L51-L70)、[src/i2s_receive.v:L117–L132](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/i2s_receive.v#L117-L132)。
- 触发：在已有运行状态下，麦克风 BCLK 已为低、WS 为低、WS 分频器 `cnt_n=31` 或32时断言 `rst_n`。这是可到达的时序相位，不需要非法输入。
- 原因：BCLK 发生器复位后保持低；其下游 WS 分频器使用输入时钟边沿上的同步复位。若 BCLK 原本已低，就没有新的下降沿去复位 WS 的 `cnt_n/clk_n`，也没有后续上升沿。即使复位保持很久，WS 的旧相位仍可能保留。接收器 `b_cnt` 却被异步清零，两个计数基准因此不同。
- 新 bridge 只要见过一个 WS 下降沿就永久 `frame_armed=1`；它没有确认接下来被接受的 left_complete 确实来自这个边界之后完整收取的左声道。

**可由 RTL 推导的反例，未运行仿真：** 令保留的 WS `cnt_n=32,clk_n=0`。释放后以 Pj/Nj 表示第j个 BCLK 上升/下降沿：

| 边沿 | 源接收器/WS 行为 | 新 bridge 的后果 |
|---|---|---|
| N1 | WS 因旧cnt_n=32变高 | 只是恢复在旧的半帧相位 |
| N33 | WS 变低 | 在50 MHz域同步后设置 frame_armed |
| P34 | 接收器旧b_cnt=33，发布此前启动阶段拼出的左数据；finished_left拉高 | 这不是从N33开始收满的左样本 |
| P35 | WS检测使b_cnt清零；finished_left下降 | 延迟后的left_complete被接受，left_pending置1 |
| P36 | 旧b_cnt=0，提前发布右数据并拉高finished_right | 此时N33之后仅经过几个BCLK，右声道尚未完整接收 |
| P37 | finished_right下降 | 延迟后的right_complete消耗left_pending，输出一次错误的frame_valid |

当前一个 BCLK 约16个系统周期，N33的帧资格能在P35的完成下降沿被捕获前生效，所以这个反例不是“也许两个同步器偶然反序”的猜测。保留cnt_n=31也可形成相同问题，只是首个WS下降和右发布相位各后移。

- 后果：复位恢复后，下游会把一份不完整/错配的启动数据当成有效立体声样本；IIR/AGC状态也可能接收它。之后重新对齐不撤销已接受的伪帧。
- 建议：使分频器/接收器的复位相位可靠，并从源端以真实完整帧资格生成完成信号；或在新bridge中要求帧边界后先经过对应WS上升阶段，再接受左完成。**不要简单在每个WS下降沿清left_pending**，因为正常的右完成本来就在下一个WS下降沿之后发布。
- 建议检查，未执行：遍历BCLK高/低及WS计数相位，特别是cnt_n=31/32的低BCLK复位，断言首次valid一定晚于独立发送端完整左右字的结束。现有 [sim/i2s_receive_tb.sv:L193–L208](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/sim/i2s_receive_tb.sv#L193-L208) 在第二轮前于BCLK上升沿之后7 ns复位，未覆盖上述停止低电平的情形。
- 来源边界：同步分频器本身是旧代码；本次新增的是对其原始完成事件赋予“完整帧有效”语义，当前资格条件不足。正常稳态配对并未因此被判为错误。

### F02 · P1 · 每结果只写一次已经修正，但速率不匹配仍使 DAC FIFO 长期满并丢样

**来源：既有时钟/流量问题在新提交中仍未闭合；不是“改成脉冲写”本身出错。**

- 位置：[src/top.v:L351–L389](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/top.v#L351-L389)；[src/i2s_receive.v:L42–L59](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/i2s_receive.v#L42-L59)；[src/clkdiv.v:L16–L59](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/clkdiv.v#L16-L59)；[src/i2s_tx.v:L44–L60](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/i2s_tx.v#L44-L60)、[src/i2s_tx.v:L121–L140](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/i2s_tx.v#L121-L140)；[al_ip/pll.v:L13–L20](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/al_ip/pll.v#L13-L20)、[al_ip/pll.v:L61–L74](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/al_ip/pll.v#L61-L74)；[src/top.v:L148–L169](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/top.v#L148-L169)。
- 触发：普通模式、初始化完成且持续运行，麦克风按当前分频持续产出，DAC 按其 LRCK 持续消费。
- 确定的丢弃条件：`audio_process_valid=1 && dacfifo_full=1` 时，顶层把 `dacfifo_write` 置零，没有保存待写结果、重试、输出 ready 或丢弃计数。下一份结果覆盖输出后，被跳过的结果不能追回。`audio_input_overrun` 只监测输入忙，不能报告这类 DAC 丢样。
- 当前麦克风仍是 `WIDTH=4,N=17`：计数器达不到 16，实际自然 /16，再 /64。因此 50 MHz 标称输入下，算法新结果频率为 **48,828.125 帧/秒**，间隔 1024 个系统时钟。
- 不能仅照抄顶层“12.288 MHz / 48 kHz”的注释。已提交 `pll.v` 的生成信息给 C2 为 **12.328767 MHz**，参数是 CLKC2_DIV=73；而 `pll.ipc` 的目标频率字段仍写 12.288 MHz。按已提交生成 wrapper 的标称值与 /256，DAC 约为 **48,159.246 帧/秒**。这是源码配置推导，未实测 PLL，也未验证工具重新生成 IP 后采用何值。
- 按上述 wrapper 标称值，每秒多约 **668.879 帧**；8 位地址 FIFO 深度 256，在无丢弃且从空开始的理想稳态下约 **0.383 秒**的净积累量即可占满。该数值只说明数量级，启动相位、读指针同步和初始化会改变首次 full 时间。即使 DAC 真是目标 48 kHz，差额仍是 828.125 帧/秒；结论仍不变。
- 后果：FIFO 能缓冲相位差，不能消除永久速率差；长期必需丢弃样本，可能产生不连续。没有把听感、爆音或确切掉样时间当作已观察事实。
- 建议：先确定统一采样时钟或明确采样率转换方案，再设计输出缓冲、满/空策略和可见计数；若允许有损转换，明确其规则，而不是偶遇 full 就静默丢帧。仅增大 FIFO、仅加一项 pending，或只把麦克风 WIDTH 改为5，都不能解决长期速率不匹配。
- 边界：初始化前/定位模式下主动不写可属于设计意图，不与正常运行中 full 丢样混为一谈。

### F03 · P2 · AGC 仍把负满量程 -32768 的幅度统计为零

**来源：旧算法已存在，新 audio_agc_step 原样保留；不是分拍引入的数值回归。**

- 位置：[src/agc.v:L104–L106](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/agc.v#L104-L106)、[src/agc.v:L119–L122](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/agc.v#L119-L122)、[src/agc.v:L145–L161](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/agc.v#L145-L161)；旧实现同样见 [src/agc.v:L10–L18](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/agc.v#L10-L18)。
- 触发与推导：复位后增益为8192，输入 `din=-32768` 可得到 `dout=-32768`。16位补码的 `-dout` 仍为 `16'h8000`，再取 `[14:0]` 得0；在随后实际累计该输出的采样事件中，该满幅负值贡献为零。
- 后果：负满量程反馈严重低估，可能把过大信号误当低能量，影响增益调整。新旧逐位一致的参考比较会接受这个共同错误。
- 建议：另行进行算法修订时，以足够位宽求绝对值，保留幅度32768，并同步扩展累计/平均位宽或定义饱和处理；更新独立数学期望。不要在仅做兼容重构时悄悄改变数值基线。
- 相关保留行为：[src/agc.v:L168–L191](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/agc.v#L168-L191) 的 clamp_up/down 是“限制更新方向”，不是新增益的硬饱和；一步可越过2048或24576。若教学目标就是保留原算法，应明确命名/范围；若需求是严格增益限幅，则需要扩位 next_gain 加显式饱和，而不能把现代码宣传为严格钳位。

## 三、时序、CDC 与实现条件

### R01 · P1 · 50 MHz 结果直接进入 60 MHz USB 采样端，完整帧事件没有随数据跨域

**来源：既有跨域拓扑保留，本次改变了源更新时钟和时刻；条件风险，并非已观测到亚稳态。**

- 位置：[src/top.v:L285–L339](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/top.v#L285-L339)；[src/AUDIO_PROCESS_LITE.v:L86–L95](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/AUDIO_PROCESS_LITE.v#L86-L95)；[src/usb_audio_top.v:L55–L73](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/usb_audio_top.v#L55-L73)、[src/usb_audio_top.v:L147–L157](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/usb_audio_top.v#L147-L157)。
- 触发：60 MHz 域的 `audio_en` 消费沿靠近50 MHz域结果更新沿，或两端采样率不同。
- 原因：USB端接的是 `audio_l_process/audio_r_process` 两条16位总线，却不消费 `audio_process_valid`，也没有与本次结果对应的握手或异步FIFO；USB内部bufi只是60 MHz域采样后的缓存，不是50→60 MHz整帧CDC。
- 后果：在未约束/未满足采样时序时有多位混合或左右一致性风险。即使物理采样始终可靠，约48.828 kHz产出对USB的48 kHz取样也不保证逐结果恰好一次，仍会跳过源样本。
- 限定：50与60 MHz同源于板载时钟和PLL，不应武断说成完全无关的异步时钟；也不能因同源就省掉相关时钟约束和整帧交付协议。保持总线大部分时间稳定不等于已经证明消费沿避开变化。
- 建议：在明确的时钟/采样率方案下跨域传递一份原子立体声记录，采用适合速率关系的FIFO/握手与采样率转换；只给每个位各加两拍无法保证整字一致，也不能解决永久速率差。

### R02 · P2 · 输入 bundled-data 方法有合理稳定窗口，但仍依赖实现约束

- 位置：[src/mic_serial.v:L66–L124](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/mic_serial.v#L66-L124)；源发布 [src/i2s_receive.v:L117–L132](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/i2s_receive.v#L117-L132)；约束入口 [USB.al:L239–L268](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/USB.al#L239-L268)、[IO.adc:L1–L27](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/IO.adc#L1-L27)。
- 已确认：源PCM在完成信号上升时更新；新逻辑等待该完成信号下降，再经过控制同步/边沿检测捕获PCM。当前完成电平约为一个BCLK，比50 MHz周期长得多，数据在捕获前已有至少一个BCLK的稳定时间。不是只在完成刚拉高时抢读，也没有把数据逐位双拍宣称为整字CDC。
- 条件：控制脉冲必须能被捕获，数据最长路径要落在稳定窗口内，源数据必须保持到捕获完成；新接口仍是开环，没有反压源端。频率、路由或源协议改变后，应重新证明这些条件。
- 风险与建议：约束生成时钟、源/目的路径与复位释放，给同步器正确属性和实现检查；若无法保留稳定窗口，改为确认握手或FIFO。已读IO.adc主要是引脚配置，未取得数据路径/CDC/STA签核证据；这不等于断言工具绝不会自动推导时钟或本地没有额外约束。
- R02讨论物理条件；F01的错误则在理想数字时序下即可发生，不能用“补CDC约束”替代资格逻辑修复。

### R03 · P2 · 分拍改善组合深度，但不能据此断言50 MHz已收敛或器件资源足够

- 位置：[src/iir.v:L108–L138](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/iir.v#L108-L138)、[src/agc.v:L108–L122](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/agc.v#L108-L122)；实例范围 [src/AUDIO_PROCESS_LITE.v:L102–L225](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/AUDIO_PROCESS_LITE.v#L102-L225)。
- 新设计在14个IIR实例内分别寄存乘积、缩放、加减和最终状态，AGC也拆开乘法/缩放；没有看到这段控制中新引入的组合锁存器、多驱动或普通脉冲直接作时钟。
- 乘法现在由行为式 `*` 描述，而旧默认IIR使用显式厂商DSP实例。常系数优化、DSP/LUT映射、宽寄存器成本及关键路径取决于目标工具。除法为常数且需保持有符号向零截断，不能无条件替成 `>>>`。
- 建议：以后仅在另行授权实现验证时检查目标器件映射、资源、时序与复位网络；当前只能确认分拍边界和逻辑语义，不能把作者的通用工具proc/opt/check描述等同安路布局布线或STA通过。

## 四、核心流水线的正向核对与使用契约

### 逐拍控制

以一份 `in_valid && in_ready` 被接受的系统时钟沿为C0；证据为 [src/AUDIO_PROCESS_LITE.v:L50–L98](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/AUDIO_PROCESS_LITE.v#L50-L98)、[src/iir.v:L103–L138](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/iir.v#L103-L138)、[src/agc.v:L119–L122](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/agc.v#L119-L122)：

| 时刻 | 行为 |
|---|---|
| C0 | 锁存左右样本、audio_ref及同步后的模式；转LAUNCH |
| C1 | 14路IIR与2路AGC共同sample_en；各自读取输入/旧状态 |
| C2 | IIR乘积入寄存器；AGC结果与done产生 |
| C3 | IIR缩放；顶层记住较早到达的AGC完成 |
| C4 | IIR加法 |
| C5 | IIR减法及下一状态值 |
| C6 | IIR统一提交状态/结果并产生filter_done |
| C7 | 顶层看到全部filter_done，发布左右结果与一拍out_valid，回IDLE |
| C8 | 最早接受下一份输入；DAC顶层看到上一拍out_valid，登记写使能和数据 |
| C9 | DAC FIFO真正看到登记后的写使能并接受数据，前提是许可条件满足 |

因此固定延迟为 **7个周期（50 MHz下140 ns）**，最小输入接受间隔为 **8个周期（160 ns）**。当前麦克风1024周期一帧，正常条件下有充分计算吞吐余量。不能把“约8拍”误读为8个并行样本或每拍可接收。

1. 全部14个IIR控制阶段完全一致，42位低音实例也不改变控制延迟，所以当前 `&filter_done` 的同时脉冲判断成立。如果未来某路延迟不同，应逐路累计完成位；这只是维护条件，不能报成当前必然死锁。
2. AGC先完成，其done由seen位保留，直到IIR完成；不存在等待期间漏掉AGC短脉冲的问题。
3. 输入、参考幅度和模式在C0锁存，计算期间外部输入变化不改变当前事务。旁路也在C7寄存输出并给valid；输出在其他拍保持。
4. 顶层DAC写使能/数据再寄存一拍，FIFO再于下一沿消费，这本身不是数据/valid错位。当前没有连续每拍写入，也没有发现这个一拍延迟制造正常条件下的重复提交。满时直接丢弃另见F02。
5. `out_valid` 是事件接口，没有out_ready；消费者须当拍接受或缓冲。麦克风frame_valid也不会等ready；若将来算法超过帧间隔，输入会丢失，overrun仅记一次且可能被优化掉。当前固定1024对8周期关系下不将其列为已发生的忙时丢样。
6. reset_sync与frame_reset_sync提供各自50 MHz域异步断言、同步释放；在途计算会清空。帧桥与AUDIO_PROCESS使用rst_n，不跟随定位专用rst_dsp，有意避免定位重启打断音频。此局部正确性不修复F01中更上游分频器的复位相位。

### 数值、符号和旧样本关系

- 默认IIR用41位状态/差值，41×16→57位有符号乘积；反馈除1024，输出除8192，写回时保留低位。基线DSP配置确为对应的有符号组合乘法，参考替身与该配置吻合。
- 低音两实例保留42位状态和42位乘积截断，除4096/65536。旧 `iir_ch` 的表达式语境本就只有42位；不能误报为新模块少留乘积位，也不能在兼容重构中随意扩位。
- AGC保留32位乘积、除8192以及16位输出截断。负数有符号除法向零截断和算术右移向负无穷取整不同，当前代码没有误换。
- 所有IIR/AGC同拍launch，因此级联后级仍读取前级上一事务的输出；启用AGC时也仍读取所选滤波器的旧输出。这是旧同采样沿/NBA结构的样本关系，并非“新流水少等待一级”。将AGC改为滤波完成后才launch会改变原数值序列。
- AGC的计数/统计和增益更新都由sample_en门控。更新标志在空闲期间保持，不会让增益每个50 MHz周期重复调整。新增长/短平均值复位也不改变正常旧算法输出，因为旧版对应flag本就阻止其初始化前被用来改增益。
- 两级同步的拨码位是独立控制，不保证多个开关原子变化或机械消抖；代码已说明。通用使用中，复位刚释放即接收可能锁存尚未填满的默认模式；当前麦克风启动时距足够，不当作现有集成回归。
- 独立复用audio_iir_step必须在空闲时给sample_en；独立复用audio_agc_step若连续每拍给sample_en，反馈年龄不再等同原单沿AGC。当前上层8拍间隔不受影响，应把这种间隔前提写进复用契约。
- 定宽截断、无饱和、增益方向门控和窗口统计规则是本次保留的数值选择。它们能满足“与旧实现一致”的教学目标，但不能单凭一致性宣布音质、频响、溢出策略或AGC数学设计正确。

## 五、测试资产的静态评价

### V01 · P2 · 首帧激励重复且右路为零，缺少独立“已完整发送”资格

**来源：本次新增首帧检查的验证缺口，不是另一项已复现的DUT缺陷。**

- 位置：[sim/i2s_receive_tb.sv:L50–L70](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/sim/i2s_receive_tb.sv#L50-L70)、[sim/i2s_receive_tb.sv:L74–L103](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/sim/i2s_receive_tb.sv#L74-L103)、[sim/i2s_receive_tb.sv:L121–L132](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/sim/i2s_receive_tb.sv#L121-L132)。
- frame0～2进入默认分支，`frame-11` 为负移位量，基值为零；加通道标签后这三帧仍重复，右声道channel0为零。`right_id` 在右时隙刚开始时就更新，checker只核对编号和内容，没有独立确认右24位已发送完毕。
- 后果：若一种启动错误在左数据已有后过早使用复位/上一帧零右值，这个“首个完整帧”检查可能看起来正确；内容相等和编号正确并不足以证明采完。这里不声称该特定伪通过已在当前DUT运行出现。
- 建议：从frame0开始就给左右不同、跨帧不同、非零且高16位明显不同的值，并用发送端独立完成队列或最早valid时刻断言核对。结合F01补齐低BCLK复位相位。

### 实际覆盖与缺口

| 性质 | 源码能确认的安排 | 限定 |
|---|---|---|
| 全部开关组合、优先级 | 算法TB遍历64种模式，每种40帧 | 验证参考为旧实现，不是独立频响/数学黄金模型 |
| 有符号、负满量程、舍入值 | drive_sample含0、-1、32767、-32768、-1025、8191及固定种子序列 | 共同算法缺陷如F03仍可逐位一致 |
| 输入背压与锁存 | valid保持到ready，接受后改变音频输入；变化空闲间隔 | out_ready不存在，没有下游背压场景 |
| 输出记账、稳定性、延迟 | pending、重复检查、非valid时输出不变、age==7、超时 | 是源码中的检查意图，本轮未运行 |
| 算法复位中止 | 接受后7个不同中止偏移，再继续64帧 | 不等于所有接收器/分频器相位，也未覆盖valid跨复位一直保持 |
| 新frame_valid逐帧记账 | 要求right_id连续，拒绝相邻重复，并检查同对左右样本 | 明显优于上一轮总数检查；仍有V01和F01覆盖空窗 |
| 接收器到算法旁路 | I2S TB例化mic_serial+AUDIO_PROCESS，全部开关为0 | “端到端”只到算法旁路输出，不含USB、DAC、顶层门控或FIFO满/空 |
| 旧七路完成/流水 | finished上升后#100检查，跳过frame0～2，核对事件总数 | 不检查电平宽度、start、立即复位状态；漏/重复可在总数上抵消 |
| 独立DSP复位、左右等待配对中复位 | TB把rst_dsp与rst_n绑一起；中途复位在左时隙 | 没覆盖left_pending持有完整左半帧等待右侧、frame_valid期间、DSP单独复位 |
| 精确采样率、CDC和器件实现 | 发送端跟随DUT的BCLK/WS，有限固定发送延迟 | 无独立频率保证，不能替代真实时序/CDC/RDC与长期流量检查 |
| 运行脚本 | 两个明确-s顶层、编译及vvp退出码、零/Z各一次，产物放临时目录 | 未执行，也不包含顶层USB/DAC集成或安路实现验证 |

证据：[sim/audio_process_tb.sv:L31–L87](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/sim/audio_process_tb.sv#L31-L87)、[sim/audio_process_tb.sv:L89–L177](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/sim/audio_process_tb.sv#L89-L177)；[sim/i2s_receive_tb.sv:L16–L30](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/sim/i2s_receive_tb.sv#L16-L30)、[sim/i2s_receive_tb.sv:L161–L221](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/sim/i2s_receive_tb.sv#L161-L221)；[sim/run_audio_process.ps1:L7–L33](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/sim/run_audio_process.ps1#L7-L33)。

### 作者测试计数与源码是否相符

- 算法预期完成数：`64×40 + 2200 + 64 = 4824`；另有7次有意复位中止，接受总数应为4831。TB最终检查accepted=checked+aborted及aborted=7。
- 七路比较：每次运行 `2 epoch ×100帧×7路=1400`；零/Z两次合计2800。
- 新立体声与旁路输出：每次 `2 epoch×103帧=206`；两次合计412。比旧400帧多出的12帧来自每epoch的启动编号0～2。
- 这些数字与作者说明的计数口径相符，**只确认设计了这些检查，不确认执行、通过或无遗漏**。算法参考复用了旧RTL，厂商DSP为行为替身，不把它视为厂商原语实仿。

## 六、上一轮问题的状态

| 上轮项 | 本轮状态 |
|---|---|
| F01：wide finished被50 MHz消费者重复计数 | 新音频frame接口用下降沿转成单事件，避开了这一路问题；旧mic输出/start和xcorr存储连线仍使用wide finished，原问题未全修复 |
| F02：接收器启动伪finished_right | 原始i2s_receive未改；新frame_armed+left_pending能屏蔽正常复位对齐路径的早右完成，但F01反例说明“首个完整帧”保证仍不充分 |
| F03：WIDTH4/N17实际/16 | 未改，已纳入本轮F02采样率分析；增宽到5也不会自然得到48 kHz |
| F04：mic_data_left3_d2漏复位 | 仍未赋值，mic_serial第147行仍重复复位right3_d0；新音频路径直接读raw left1/right1所以不经过该通道，但旧mic_5/定位路径未修复 |
| R01：派生时钟、整字传递无实现依据 | 新frame桥和统一算法时钟缩小了风险范围；USB跨域、物理约束和复位相位仍未闭合 |
| V01：只查总数、不查逐帧 | 新frame_valid checker已补连续编号、脉宽/重复和配对，属于有效改进；旧七路计数、first-frame激励及复位相位仍有缺口 |

旧路径当前证据：[src/mic_serial.v:L129–L198](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/mic_serial.v#L129-L198)；[src/top.v:L215–L247](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/top.v#L215-L247)；[src/mic_data_store.v:L57–L93](https://github.com/Lucian-prog/FPGA/blob/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/mic_data_store.v#L57-L93)。此表更新既有结论，不将它们再计为本次新增RTL回归。

## 七、建议顺序与交付边界

1. 先修正并明确首个完整帧资格，覆盖停止低电平BCLK复位，不以多等待固定几帧掩盖根因。
2. 统一麦克风、DAC与USB的采样率策略；解决DAC full丢弃和USB原子整帧交付，核实目标PLL配置与生成wrapper的频率差异。
3. 若继续沿用旧算法，明确固定点截断/窗口/增益范围；若修AGC负满量程，作为单独数值规格变更配套独立期望。
4. 保留本次合理的同步事件、统一计算时钟、数据/模式锁存和分拍结构；不要为“修复级联延迟”而无意改变原样本代际。
5. 上述测试/实现检查仅为后续建议，**本轮没有启动任何测试**，也没有修改任何源代码。

本报告的已审源检查点为 `b611af4b8bb945684ba8c0e86720dadaa4f3ea3a`。文档提交只追加本文件，不强推、不改写历史、不合并或部署；静态审查结论不代表实现已通过、所有问题已修复或可直接上板。
