# FPGA 增量 RTL 静态审查：I2S 接收对齐修复（2026-10-04）

## 结论

本轮新增代码只有 **1 个 RTL 修改和 1 个新 testbench**。逐拍推演表明，`i2s_receive` 新增的两级 SD 流水线能够补偿原有 WS 检测和计数器的两拍偏移：在帧边界已经锁定、每声道 32 个 BCLK、有效数据为 24 位的当前接口下，左右声道的 `[31:8]` 都能对应正确的 24 位 PCM。**未发现本次 SD 延迟改动引入的明确功能回归。**

这不等于整个音频链路已经正确。沿新 TB 的例化路径检查时，发现或确认了几项**修复前已存在**的问题：完成电平被 50 MHz 逻辑当作多次样本事件、启动阶段提前报告完成、分频计数位宽不足，以及一个流水寄存器漏复位。它们与本次对齐修复分开列出，不把既有缺陷归因于新补丁。新增 TB 对稳态位准确性的检查方向合理，但不能据其计数或打印信息推断启动、事件宽度、采样率、物理时序及完整系统验证通过。

**本报告严格为离线静态源码审查。没有编译、lint、仿真、综合、形式验证、CDC/RDC 工具检查、STA 或上板测试；所有周期和数值均为源码手工推导。** 提交说明中的“Icarus 两种模式、2800 次比较通过”是作者历史报告，本轮未复现、未独立验证。本文只新增审查报告，不修改 RTL、TB、约束或已有文档。

## 一、版本、分支与范围

- 仓库：[Lucian-prog/FPGA](https://github.com/Lucian-prog/FPGA)，默认分支 `main`。
- 本轮分支清单只返回 `main`；审查源 SHA 为 [`8895c004848271d7708644ce6f58f05dc68c63dc`](https://github.com/Lucian-prog/FPGA/commit/8895c004848271d7708644ce6f58f05dc68c63dc)。
- 直接比较基线为上一份报告提交 [`c77adb25e6cdf022b4046ec1502d96c419465dcf`](https://github.com/Lucian-prog/FPGA/commit/c77adb25e6cdf022b4046ec1502d96c419465dcf)。GitHub compare 返回 `ahead_by=1`、`behind_by=0`，恰好两个源码文件变化。
- 上一个源代码检查点为 [`bd2a1df56e09af168c97522b341f412f814cec47`](https://github.com/Lucian-prog/FPGA/commit/bd2a1df56e09af168c97522b341f412f814cec47)。父提交链为 `bd2a1df → c77adb2（仅 Bagu 报告）→ 8895c00（本次代码）`。因此审查范围来自分支和提交差异，不是仅凭日期筛选。
- 已检查既有 [Bagu 报告](https://github.com/Lucian-prog/FPGA/blob/8895c004848271d7708644ce6f58f05dc68c63dc/docs/code-reviews/Bagu-review-2026-10-03.md) 的基线和覆盖范围；它只覆盖 Bagu，本次不是重复审查 Bagu，也不是对全仓库既有源码的全量签核。
- 当前完整递归树为 470 个条目，`truncated=false`。已读根 [AGENTS.md](https://github.com/Lucian-prog/FPGA/blob/8895c004848271d7708644ce6f58f05dc68c63dc/AGENTS.md)，音频目录和本次报告目录没有更深层适用的 AGENTS.md。
- 已读实际存在的内层 [项目 README](https://github.com/Lucian-prog/FPGA/blob/8895c004848271d7708644ce6f58f05dc68c63dc/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/README.md) 和 [README.md](https://github.com/Lucian-prog/FPGA/blob/8895c004848271d7708644ce6f58f05dc68c63dc/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/README.md)。根说明所提外层音频目录没有单独 README，已以树中实际内层文档为准。
- 下文短路径统一相对于 `18. 2025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/`；所有源码证据固定到本轮源 SHA。
- 只有 `docs/code-reviews/` 报告变化的提交不算新的 RTL 审查输入。本报告记录的“已审源 SHA”始终为 `8895c004...`，不以报告自身提交冒充新源码。

### 覆盖清单

| 文件 | 本轮状态 | 阅读与检查范围 |
|---|---|---|
| [src/i2s_receive.v](https://github.com/Lucian-prog/FPGA/blob/8895c004848271d7708644ce6f58f05dc68c63dc/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/i2s_receive.v) | 修改，+14/-7，当前 136 行 | 全文；SD/WS流水、NBA旧值、计数、左右位索引、发布时刻、复位和实例参数 |
| [sim/i2s_receive_tb.sv](https://github.com/Lucian-prog/FPGA/blob/8895c004848271d7708644ce6f58f05dc68c63dc/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/sim/i2s_receive_tb.sv) | 新增，167 行 | 全文；独立发送模型、7路比较、数据花样、事件计数、复位、超时和检查空窗 |
| [src/clkdiv.v](https://github.com/Lucian-prog/FPGA/blob/8895c004848271d7708644ce6f58f05dc68c63dc/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/clkdiv.v) | 未变，依赖 | 全文；实际分频、计数宽度、双沿时钟和同步复位 |
| [src/mic_serial.v](https://github.com/Lucian-prog/FPGA/blob/8895c004848271d7708644ce6f58f05dc68c63dc/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/mic_serial.v) | 未变，直接调用方 | 全文；通道映射、数据流水、完成信号消费和启动条件 |
| [src/top.v](https://github.com/Lucian-prog/FPGA/blob/8895c004848271d7708644ce6f58f05dc68c63dc/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/top.v) | 未变，集成上下文 | 全文阅读；本报告只评价本次接收链相关的时钟、复位及消费者连线，不签核其他顶层功能 |
| [src/mic_data_store.v](https://github.com/Lucian-prog/FPGA/blob/8895c004848271d7708644ce6f58f05dc68c63dc/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/mic_data_store.v) | 未变，下游依赖 | 全文；样本事件与地址推进、BRAM写使能 |
| [src/xcorr.v](https://github.com/Lucian-prog/FPGA/blob/8895c004848271d7708644ce6f58f05dc68c63dc/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/xcorr.v) | 未变，下游连线 | 全文阅读；本报告仅使用末尾两路存储实例的完成信号映射，不评价互相关算法正确性 |
| [src/AUDIO_PROCESS_LITE.v:L1–L115](https://github.com/Lucian-prog/FPGA/blob/8895c004848271d7708644ce6f58f05dc68c63dc/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/AUDIO_PROCESS_LITE.v#L1-L115) | 未变，节选 | 仅1–115行，确认输入数据进入另一个采样时钟的滤波器；未全查滤波/AGC链 |
| [USB.al](https://github.com/Lucian-prog/FPGA/blob/8895c004848271d7708644ce6f58f05dc68c63dc/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/USB.al)、[IO.adc](https://github.com/Lucian-prog/FPGA/blob/8895c004848271d7708644ce6f58f05dc68c63dc/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/IO.adc) | 未变，工程上下文 | 全文；源文件/约束入口及引脚配置，不等于工具已验证约束有效 |
| 两级 README、根 AGENTS.md、上一报告版本/范围 | 文档上下文 | 用于确认平台、接口和审查边界；不将文档中的历史测试结果算成本轮结果 |

新增代码覆盖为 **2/2 文件**。没有读取或执行生成的 EDA 产物，也没有把其他旧 TB、其他音频模块或其他编号练习算作本轮已全审。

### 分级与来源标记

- **P1 高**：可能直接损坏样本流/采集语义，修复相关功能前应优先处理。
- **P2 中**：确定的边界、参数或启动问题，或明显验证缺口。
- **P3 低**：可复用性与文档改进。
- **确定缺陷**：给定触发条件，可由 RTL 推导；**条件风险**：还依赖使用契约或实现条件，不声称硬件已经失败。
- **既有**：本次两文件差异之前就存在；**新增验证局限**：新 TB 没覆盖某性质，不等于该性质已经失败。
- 当前工程是学习/竞赛仓库，允许明确限定的教学接口。固定24位、固定7路等范围本身不作为缺陷；但对真实采样事件或48 kHz的需求不能用“学习代码”代替契约说明。

## 二、明确的既有功能问题

### F01 · P1 · 完成信号是一个 BCLK 宽的电平，下游却每个 50 MHz 周期都计一次样本

**来源：既有集成缺陷，本次补丁未引入也未修复。**

- 位置：[src/i2s_receive.v:L117–L132](https://github.com/Lucian-prog/FPGA/blob/8895c004848271d7708644ce6f58f05dc68c63dc/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/i2s_receive.v#L117-L132)；[src/mic_serial.v:L87–L100](https://github.com/Lucian-prog/FPGA/blob/8895c004848271d7708644ce6f58f05dc68c63dc/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/mic_serial.v#L87-L100)、[src/mic_serial.v:L123–L130](https://github.com/Lucian-prog/FPGA/blob/8895c004848271d7708644ce6f58f05dc68c63dc/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/mic_serial.v#L123-L130)；[src/mic_data_store.v:L57–L71](https://github.com/Lucian-prog/FPGA/blob/8895c004848271d7708644ce6f58f05dc68c63dc/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/mic_data_store.v#L57-L71)、[src/mic_data_store.v:L87–L93](https://github.com/Lucian-prog/FPGA/blob/8895c004848271d7708644ce6f58f05dc68c63dc/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/mic_data_store.v#L87-L93)；下游映射见 [src/xcorr.v:L169–L189](https://github.com/Lucian-prog/FPGA/blob/8895c004848271d7708644ce6f58f05dc68c63dc/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/xcorr.v#L169-L189) 和 [src/top.v:L240–L276](https://github.com/Lucian-prog/FPGA/blob/8895c004848271d7708644ce6f58f05dc68c63dc/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/top.v#L240-L276)。
- 触发：正常工作时出现一次 `finished_left/right`；对于存储地址问题，还需 `start_flag=1`，即正在采集定位数据。
- 原因：接收器把完成信号拉高到下一次 BCLK 上升沿。现有分频在50 MHz输入下一个BCLK为320 ns，相当于16个50 MHz周期。`mic_serial.cnt_start` 在整个高电平内每拍加一，所以 `cnt_start==3` 在第一次左完成电平内就能满足，并非等到第四个左样本。`mic_data_store.ada_cnt` 也直接用同一高电平逐拍递增。
- 后果：一次音频样本能推进约16个存储地址，而非一次；`cea=start_flag` 又持续写入，采集缓冲区可能包含重复或过渡期数据，1024地址不再代表1024个独立音频时刻，定位计算输入的采样语义被破坏。这里的重复事件是数字逻辑就能推出的问题，不需要先假设亚稳态。
- 建议：在消费域形成**每个完成事件恰好一拍**的 `sample_valid`，并使它与稳定的新样本对齐；用同一接受条件推进地址、写BRAM和统计启动样本。相关派生时钟可采用有明确时序约束的同步方案；若改为真正异步域，用握手或异步FIFO传递整字。不能只加一个过早的边沿脉冲就认为三拍数据流水已对齐。
- 建议检查，未执行：对每个WS帧，分别断言左右各一次样本接受、地址各加一、BRAM各一次写入；核对 `start` 的约定究竟是等第四个样本还是只等流水线稳定。若启动计数本就只想等待四个系统时钟，应改名/说明，存储重复计数仍需单独修复。

### F02 · P2 · 复位后尚未收满右声道即发布 finished_right

**来源：既有启动缺陷；提交说明和新 TB 已明确排除启动有效性。**

- 位置：[src/i2s_receive.v:L62–L70](https://github.com/Lucian-prog/FPGA/blob/8895c004848271d7708644ce6f58f05dc68c63dc/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/i2s_receive.v#L62-L70)、[src/i2s_receive.v:L105–L128](https://github.com/Lucian-prog/FPGA/blob/8895c004848271d7708644ce6f58f05dc68c63dc/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/i2s_receive.v#L105-L128)；新 TB 的排除条件见 [sim/i2s_receive_tb.sv:L112–L132](https://github.com/Lucian-prog/FPGA/blob/8895c004848271d7708644ce6f58f05dc68c63dc/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/sim/i2s_receive_tb.sv#L112-L132)。
- 触发：`rst_n` 释放后的第一个 BCLK 上升沿。
- 原因与后果：`b_cnt` 复位为0，发布过程读取旧值0，立即置 `finished_right=1` 并输出复位后的 `R_data[31:8]`。此时根本没有收满24位右声道。这是无效零样本被标为完成；复位阶段与WS相位不一致时，首个左输出也不能仅靠自由运行计数就保证属于完整帧。
- 建议：增加帧锁定和每半帧完成资格，从有效WS边界开始计数，只有已采满有效位才发布；或明确接口启动无效区间并让所有消费者共同遵守。不要仅在TB中丢弃几帧、硬件仍把每个 `finished` 当有效。
- 建议检查，未执行：初次上电、左右槽中途复位、不同WS相位释放；从释放开始追踪第一笔有效样本。TB现有“frame_id≥3”仅检查重新对齐后的稳态，不能证明首帧无伪完成。

### F03 · P2 · WIDTH=4 与 N=17 不匹配，实际并不是17分频

**来源：既有确定参数错误；作者提交已说明分频不在该修复范围。**

- 位置：[src/i2s_receive.v:L42–L59](https://github.com/Lucian-prog/FPGA/blob/8895c004848271d7708644ce6f58f05dc68c63dc/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/i2s_receive.v#L42-L59)；[src/clkdiv.v:L16–L39](https://github.com/Lucian-prog/FPGA/blob/8895c004848271d7708644ce6f58f05dc68c63dc/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/clkdiv.v#L16-L39)、[src/clkdiv.v:L42–L59](https://github.com/Lucian-prog/FPGA/blob/8895c004848271d7708644ce6f58f05dc68c63dc/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/clkdiv.v#L42-L59)；50 MHz输入连线见 [src/top.v:L186–L203](https://github.com/Lucian-prog/FPGA/blob/8895c004848271d7708644ce6f58f05dc68c63dc/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/top.v#L186-L203)。
- 触发：当前默认实例参数，无需异常输入。
- 原因：4位 `cnt_p/cnt_n` 只能取0～15，永远达不到终值 `N-1=16`，于是自然按16回绕。
- 后果：稳态输出周期为16个输入周期，50 MHz / 16 = **3.125 MHz**；再除64得到 **48,828.125 Hz**，相对48 kHz约高1.7253%。这不是注释中的3.072 MHz，也不是17分频。新TB跟随DUT自己的BCLK/WS生成串行数据，因此可以在频率不符合目标时仍通过位内容比较。
- 建议：先明确目标采样率和整个音频时钟体系；给分频器加合法参数约束，计数宽度至少能表示 `N-1`。仅把WIDTH改成5会得到50 MHz/17/64≈45,955.882 Hz，**仍不是48 kHz**；准确音频时钟应选能满足目标频率的时钟来源/分频方案，并一起检查下游采样时钟。
- 限定：源注释本来就承认近似频率，若原意仅是近似演示，应明确实际速率及其边界；“N=17却实际/16”仍是确定不一致。对真实录音的具体音高、掉样或滤波影响，还取决于后续采样方式，本轮不宣称已在硬件观察到。
- 建议检查，未执行：量测BCLK周期/高低宽度、64 BCLK一帧、WS实际频率，检查非法参数能否明确报错；这些属性应独立于发送模型的数据比较。

### F04 · P2 · mic_serial 的左侧第3路输出寄存器漏复位

**来源：既有确定的复位遗漏，影响在启动/独立DSP复位时显现。**

- 位置：声明 [src/mic_serial.v:L44–L58](https://github.com/Lucian-prog/FPGA/blob/8895c004848271d7708644ce6f58f05dc68c63dc/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/mic_serial.v#L44-L58)；复位清单 [src/mic_serial.v:L62–L85](https://github.com/Lucian-prog/FPGA/blob/8895c004848271d7708644ce6f58f05dc68c63dc/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/mic_serial.v#L62-L85)；更新链 [src/mic_serial.v:L98–L100](https://github.com/Lucian-prog/FPGA/blob/8895c004848271d7708644ce6f58f05dc68c63dc/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/mic_serial.v#L98-L100)。
- 触发：初次复位或已有样本后再次断言 `rst_dsp`，直至下一次左完成使能更新输出。
- 原因与后果：`mic_data_left3_d2` 没有在复位分支赋值，而 `mic_data_right3_d0` 被重复清零。`mic_5` 直接连接这个d2，因此初次复位期间及释放后第一次左完成使能之前，RTL仿真中可能保持X；后续DSP复位时则可能保持旧样本。其d0/d1确实已复位，第一次左使能会把d2更新为0，随后才推进新样本。若使用者依赖七路输出在复位期间统一归零，或在重新有效前读取 `mic_5`，该通道行为就与其他通道不一致。
- 建议：补齐对应d2复位并消除重复项；确认 `rst_n` 与 `rst_dsp` 的独立复位契约，以及输出valid与三拍流水的关系。
- 建议检查，未执行：先装入非零样本再只拉低 `rst_dsp`，逐个50 MHz周期检查7路流水；现有TB将两个复位绑在一起、丢弃前几帧并延后100 ns采样，不覆盖这个瞬态。不能把本文的静态X/旧值推断说成已运行复现。

## 三、本次两拍修复的逐拍核对

证据：[src/i2s_receive.v:L19–L39](https://github.com/Lucian-prog/FPGA/blob/8895c004848271d7708644ce6f58f05dc68c63dc/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/i2s_receive.v#L19-L39)、[src/i2s_receive.v:L62–L100](https://github.com/Lucian-prog/FPGA/blob/8895c004848271d7708644ce6f58f05dc68c63dc/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/i2s_receive.v#L62-L100)、[src/i2s_receive.v:L117–L128](https://github.com/Lucian-prog/FPGA/blob/8895c004848271d7708644ce6f58f05dc68c63dc/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/i2s_receive.v#L117-L128)；发送约定见 [sim/i2s_receive_tb.sv:L58–L95](https://github.com/Lucian-prog/FPGA/blob/8895c004848271d7708644ce6f58f05dc68c63dc/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/sim/i2s_receive_tb.sv#L58-L95)。

以下只讨论**已经锁定WS帧边界的稳态**。定义N0为WS下降的BCLK下降沿，P0为随后第一个上升沿；N1发出左MSB，P1采到它。每一行的判断都使用该上升沿之前的寄存器旧值。

| 时刻 | 控制与数据行为 | 结论 |
|---|---|---|
| P0 | ws_d1采到0，ws_d0仍来自此前高电平 | 沿后neg_clk_ws成立；计数器此沿尚未据此复位 |
| P1 | neg_clk_ws旧值为1，b_cnt清0；data_d0采入左MSB | WS检测与数据开始基准建立 |
| P2 | 旧b_cnt=0，递增到1；data_d1接到P1的MSB | 此沿的右输出是上一帧末尾，启动情况须另按F02限定 |
| P3 | 旧b_cnt=1，采旧data_d1至L_data[31] | 正好使用P1的左MSB，不再使用P3的新串行位 |
| P3～P26 | 旧b_cnt=1～24，写L_data[31:8] | 左24位完整进入输出有效区 |
| N32/P33 | WS在N32升高，右MSB在N33发出并于P33采入 | 右声道同样保留一个I2S位延迟 |
| P35 | 旧b_cnt=33，写R_data[31]，同时发布L_data[31:8] | 右MSB与已收满的左样本分别正确处理 |
| P35～P58 | 旧b_cnt=33～56，写R_data[31:8] | 右24位完整进入输出有效区 |
| P66 | 旧b_cnt=0，发布R_data[31:8] | 右有效位早已写完；发布时刻未因修复改变 |

原版在P3直接用 `data`，对应P3采样位置而非P1，故丢掉最高两位并引入尾部位；现在使用P1经两级保存后的值，修复理由与NBA语义一致。四路串行输入都经过相同延迟，七个接收缓冲都改用 `data_d1`，没有看到某一通道漏改或左右映射倒置。

### 不应误报的设计选择

1. `data_d0/data_d1` 是BCLK域内的对齐流水；不能把它称为解决整个音频系统CDC的“两级同步器”。新增注释已经正确区分。
2. 右缓冲写索引为31～1，位0确实没写，但当前输出只用31～8。**这没有丢掉24位PCM的LSB**；只有未来扩展为32位有效数据时才需要重新设计窗口。
3. 左通道与右通道在不同半帧发布，符合当前接口；它并不承诺同一个系统时钟原子更新立体声对。
4. `data[3]` 只接右声道、合计七路，是明确的当前通道选择，不按“缺第八路”报错。
5. 尾部补零/高阻经过缓冲的低位并不自动污染输出高24位；应按实际位索引判断，不能仅因缓冲中可能有Z就判整字错误。
6. 固定24位、32位时隙是本轮采用的接口约定；没有把左对齐模式、16位时隙、任意帧长等未声明模式当作必需功能。

## 四、条件风险与新增TB的验证边界

### R01 · P2 · 派生时钟、引脚往返时序及下游整字传递没有物理签核依据

- 位置：[src/clkdiv.v:L19–L59](https://github.com/Lucian-prog/FPGA/blob/8895c004848271d7708644ce6f58f05dc68c63dc/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/clkdiv.v#L19-L59)、[src/i2s_receive.v:L24–L35](https://github.com/Lucian-prog/FPGA/blob/8895c004848271d7708644ce6f58f05dc68c63dc/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/i2s_receive.v#L24-L35)、[src/mic_serial.v:L87–L118](https://github.com/Lucian-prog/FPGA/blob/8895c004848271d7708644ce6f58f05dc68c63dc/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/mic_serial.v#L87-L118)；[IO.adc:L1–L27](https://github.com/Lucian-prog/FPGA/blob/8895c004848271d7708644ce6f58f05dc68c63dc/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/IO.adc#L1-L27)；下游时钟连接 [src/top.v:L301–L315](https://github.com/Lucian-prog/FPGA/blob/8895c004848271d7708644ce6f58f05dc68c63dc/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/top.v#L301-L315)、[src/AUDIO_PROCESS_LITE.v:L23–L49](https://github.com/Lucian-prog/FPGA/blob/8895c004848271d7708644ce6f58f05dc68c63dc/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/src/AUDIO_PROCESS_LITE.v#L23-L49)。
- 触发条件：实际综合/布线后，BCLK时钟路由、外部麦克风返回SD的建立保持、复位释放或跨域整字采样不满足所需时序。
- 风险：`clk_p & clk_n` 产生逻辑派生时钟；新增流水只能修数字拍数，不能自动保证第一拍输入采样、时钟偏斜、复位recovery/removal或多位数据一致性。麦克风BCLK来自50 MHz，二者具有派生关系，**不能简单断言它们是无关异步时钟，也不能因为有关就省掉生成时钟和时序检查**。再进入另一音频采样时钟时，还需明确如何传递完整样本及处理速率差。
- 检查范围与证据限制：本轮USB树内只发现IO.adc这份相关约束入口，其已读内容为引脚配置；USB.al中未见显式时序约束文件。不能据此断言工具不会自动推导时钟，或用户本地不存在额外约束；本轮只是没有可用的STA/CDC证据。
- 建议：按目标器件明确生成时钟、输入/输出延迟和复位策略；关系已知的域走可验证时序，真正异步/有速率差的样本流采用合适的握手、FIFO或采样率转换架构。不要用总线逐位双拍代替整字一致性，也不要把固定 `#100` 的理想TB等待当成物理证明。
- 本轮未执行以上检查。此项为条件风险，不声称新补丁制造了硬件毛刺或已发生亚稳态。

### V01 · P2 · TB的总笔数不能单独证明每帧恰好一次，也没有检查finished宽度和start

**来源：新增验证局限，不是已证实的DUT回归。**

- 位置：[sim/i2s_receive_tb.sv:L99–L132](https://github.com/Lucian-prog/FPGA/blob/8895c004848271d7708644ce6f58f05dc68c63dc/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/sim/i2s_receive_tb.sv#L99-L132)、[sim/i2s_receive_tb.sv:L135–L159](https://github.com/Lucian-prog/FPGA/blob/8895c004848271d7708644ce6f58f05dc68c63dc/18.%202025-fpga-anlogic-audio/2025-fpga-anlogic-audio-solution/USB/sim/i2s_receive_tb.sv#L135-L159)。
- 条件与后果：TB每次finished上升沿比较“当前帧的预期值”，最后只核对100次左、100次右和700次通道比较。如果某帧重复上升、另一帧漏掉，且每次实际触发时数据都对应当时帧，总数仍可能抵消；完成高电平拉长却不产生额外上升沿，也不会被总数发现。这尤其不能捕获F01的目的域重复消费。`start` 只连线，没有断言。
- 建议：按每个 `frame_id × channel` 单独记录是否已接受、是否缺失，检查完成脉冲宽度/相位、左右互斥以及目的域样本valid；对start另建明确的启动条件断言。保留总数检查，但不要让它替代逐帧记账。
- 已有优点：发送器不读取DUT的b_cnt；四态不等 `!==` 能识别预期值为确定值时的X/Z；存在错误累计、fatal和10 ms超时。这些是合理的自检基础，而非无效TB。

### 明确覆盖了什么，以及没覆盖什么

| 性质 | 从TB源码能确认的安排 | 本轮结论 |
|---|---|---|
| 7路映射/位准确性 | 每次比较raw接收输出和mic流水输出；通道标签不同 | 检查逻辑合理，未运行 |
| 符号边界、walking-one | 固定边界花样；frame 11～34遍历24个位；随后连续变化 | 只有channel 0不经XOR标签，其他通道不再是纯原始边界值；可另加所有通道共同边界轮次 |
| 尾部0与Z | `$test$plusargs("PAD_Z")` 在一次运行开始时选一种模式 | 一次运行只覆盖一种；两种需要分别运行，本轮均未运行 |
| 比较次数 | 2个epoch × 100帧 × 7路 = 1400次/运行 | 两种模式合计2800与作者描述在计数上相符，不构成运行通过证据 |
| 中途复位恢复 | 第二个epoch前在帧中复位，发送延迟由1 ns改37 ns | 只检查frame_id 3～102的重新对齐稳态 |
| 启动首帧、无伪完成 | 明确跳过前几帧 | 未覆盖，见F02 |
| 精确采样频率、非法分频参数 | 发送器跟随DUT输出BCLK/WS | 未独立检查，见F03 |
| 流水瞬态、独立DSP复位 | 两种复位绑在一起，finished后延100 ns观察 | 不覆盖F04及前几个系统时钟的数据有效性 |
| 每帧一次、完成宽度、start | 只有总事件数、未用start作检查 | 不充分，见F01/V01 |
| 完整USB/滤波/DAC/定位系统 | DUT仅mic_serial及其子模块 | 未实例化完整top，不是系统回归 |
| 器件、IO时序、CDC/RDC | 理想时钟与有限确定发送延迟 | 不能替代硬件签核，见R01 |

## 五、建议处理顺序与本轮交付边界

1. 保留本次对齐修复的核心方向；在后续任何改动中继续依据实际采样沿和NBA旧值证明时序，不用未经核对的“再延一拍”修补。
2. 优先统一完成事件与目的域样本valid，避免一个样本推进多个地址；同时定义数据流水何时可以消费。
3. 明确启动/复位契约，补齐漏复位寄存器，区分接收器复位与DSP重启。
4. 确定目标采样率后修正时钟参数与体系，不把WIDTH增加一位误当成48 kHz方案。
5. 如以后另行授权动态验证，再按V01和覆盖表补充检查并执行；本轮只给静态建议，**没有启动任何测试**。

本次审查只发布这份Markdown。上述既有缺陷和条件风险均未擅自修改；没有强推、改写历史、合并或部署。报告中的“已检查”指源文本和差异审查，不代表仿真通过、综合通过、时序收敛或可直接上板。
