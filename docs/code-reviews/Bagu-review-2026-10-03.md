# Bagu RTL 全量静态审查 2026年10月3日

## 结论

本轮已逐文件阅读 `Bagu/` 的全部 **32 个文件**：20 个设计/激励模块 Verilog 文件、8 个命名 testbench、4 个 Markdown，覆盖 13 个子目录，共 54,144 字节。当前最应优先处理的是 APB：主机输出未连接、从机默认等待计数无法结束；即使先修复这两项，主机仍有写字节选通、ACCESS 握手和读数据采样问题。原版同步 FIFO 的边界计数缺陷仍存在，但 README 已明确将它保留为复盘材料；推荐的 `sync_fifo_new.v` 不存在同一项计数缺陷。

本报告是**源代码静态分析**。所有时序反例均为根据 RTL 和非阻塞赋值语义进行的手工推演，**没有编译、lint、仿真、综合、形式验证、CDC/RDC 工具检查、时序分析或上板测试**。文中“确定”只表示可由源码推出，不表示实际运行验证通过或失败；建议测试全部未执行。本次仅新增本报告，不修改 RTL、TB 或已有笔记。

- 仓库：[Lucian-prog/FPGA](https://github.com/Lucian-prog/FPGA)
- 审查基线：[`bd2a1df56e09af168c97522b341f412f814cec47`](https://github.com/Lucian-prog/FPGA/commit/bd2a1df56e09af168c97522b341f412f814cec47)，审查开始时的 `main`
- 树清单：完整递归树返回 466 个条目、`truncated=false`；`Bagu/` 内无额外 `AGENTS.md`、约束文件或构建脚本，仓库无 `.github/` 工作流文件
- 适用说明：已阅读 [AGENTS.md](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/AGENTS.md)，按功能、仿真/综合差异、时序/复位/CDC、位宽边界的顺序审查
- 范围边界：其他编号练习、竞赛工程、`cnn_ram`、`uvm_learn` 的 RTL 不在本轮范围内
- 证据链接均固定到上述源提交，避免以后 `main` 变化导致行号漂移

### 如何理解分级

- **P1 高**：默认用法无法工作、可能造成丢事务/数据损坏，或关键 CDC/时钟路径缺乏保证；应先处理再复用。
- **P2 中**：特定输入/参数/集成条件下出错，或验证、文档问题足以掩盖错误。
- **P3 低**：表述、可移植性或工程组织改进，不直接判定当前默认功能失败。
- **确定缺陷**：触发条件成立即可由代码推导；**条件风险**：依赖接口契约、器件、布线或使用条件，不能宣称已经发生；**已知教学限制**：仓库已说明或代码有合理简化，不作为新缺陷重复指责。

## 一 明确的功能和验证缺陷

### F01 P1 APB 主机全部输出没有驱动

- 位置：[Bagu/AMBA_Bus/apb_master.v:L10-L20](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/AMBA_Bus/apb_master.v#L10-L20)、[Bagu/AMBA_Bus/apb_master.v:L35-L43](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/AMBA_Bus/apb_master.v#L35-L43)、[Bagu/AMBA_Bus/apb_master.v:L91-L147](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/AMBA_Bus/apb_master.v#L91-L147)。
- 触发：例化当前 `apb_master`，包括复位和任意读写请求。
- 原因和后果：8 个输出端口都是 `wire`，内部虽然更新 `r_PADDR/r_PWDATA/r_PWRITE/r_PSEL/r_PENABLE/r_PSTRB/r_trans_done/r_PRDATA`，却没有任何 `assign` 或其他驱动将它们接到端口。四态 RTL 语义下无驱动网络为 Z；综合可能警告并优化掉逻辑。外部不能获得有效地址、控制、数据或完成信号。
- 修复：逐一连接内部寄存器到相应端口，或将端口改为直接时序驱动并移除重复内部寄存器；特别注意 `o_SEL` 对应 `r_PSEL`、`o_tran_done` 对应 `r_trans_done`。
- 建议测试，未运行：复位后断言所有输出已知；执行一次写、一次读，检查端口真实变化，不能只观察内部寄存器。

### F02 P1 APB 从机默认等待计数永远到不了终点

- 位置：[Bagu/AMBA_Bus/apb_slave.v:L18-L38](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/AMBA_Bus/apb_slave.v#L18-L38)。
- 触发：默认 `WAIT_CYCLES=8`，持续合法 `PSEL=1 && PENABLE=1`。
- 原因和后果：`wait_cnt` 只有 2 位，循环值为 0、1、2、3，永远不等于 `WAIT_CYCLES-1=7`，因此 `o_PREADY` 始终为 0，事务永久等待。这独立于主机输出缺陷存在。
- 修复：按参数计算计数位宽，至少为 1 位；单独定义 `WAIT_CYCLES=0` 的零等待路径，并限制负数参数。当前实现对 0 或大于 4 的设置也不成立。
- 建议测试，未运行：遍历等待数 0、1、4、8，精确检查握手前低电平周期数和最终一次完成；复位打断等待后确认计数清零。

### F03 P1 APB 主机写选通一直为零

- 位置：[Bagu/AMBA_Bus/apb_master.v:L99-L121](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/AMBA_Bus/apb_master.v#L99-L121)；从机字节写条件见 [Bagu/AMBA_Bus/apb_slave.v:L48-L52](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/AMBA_Bus/apb_slave.v#L48-L52)。
- 触发：修复 F01 后发起任意写操作，目标为使用 `PSTRB` 的从机。
- 原因和后果：`r_PSTRB` 复位、空闲、WRITE 分支均为 `4'h0`，没有任何非零赋值。四个字节全部无效；即使总线握手成功，存储数据也不会变化。
- 修复：若接口只支持整字写，写时设为 `4'b1111`、读时清零；若要支持字节写，增加明确的用户 strobe 输入并与事务一起锁存。
- 建议测试，未运行：写入非零花样并回读，验证所有字节；扩展 strobe 接口后逐字节验证覆盖与保持。

### F04 P1 APB 主机状态与寄存输出错位导致提前退出或重复 ACCESS

- 位置：[Bagu/AMBA_Bus/apb_master.v:L65-L80](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/AMBA_Bus/apb_master.v#L65-L80) 与 [Bagu/AMBA_Bus/apb_master.v:L115-L138](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/AMBA_Bus/apb_master.v#L115-L138)。
- 触发：F01 修复后，SETUP 高而 ACCESS 低会提前退出；SETUP 低、进入 ACCESS 后才变高且完成后继续保持高，会出现重复完成边沿。
- 原因：次态按 `cur_state==ENABLE && i_PREADY` 判断完成，但总线输出也在时钟沿按旧 `cur_state` 更新。**状态已经叫 ENABLE 时，外部引脚仍可能在 SETUP**；握手后状态进入 DONE 时，外部引脚又可能仍多留一拍 ACCESS。
- 手工反例 A，SETUP 时 ready 高、ACCESS 时 ready 低：E1 在 IDLE 接受请求；E2 执行 WRITE/READ 输出，使 `PSEL=1,PENABLE=0`，状态进入 ENABLE；E3 因 SETUP 的 ready 高进入 DONE，同时才把 `PENABLE` 置 1；E4 执行 DONE 无条件撤销 `PSEL/PENABLE`。若 E4 的 ready 仍为 0，整个 ACCESS 没有一次有效完成，主机却已退出并稍后报告完成。
- 手工反例 B，SETUP 时 ready 低：E3 保持 ENABLE 并进入 ACCESS；之后某个有效完成沿 H 的旧状态仍是 ENABLE，因此 H 后仍保持 `PENABLE=1`，到 H+1 才撤销。若 ready 继续为 1，H+1 会再形成一次完成边沿，可能重复读副作用或写副作用。
- 修复：让 SETUP/ACCESS 状态与真实输出阶段一致，以 `PSEL && PENABLE && PREADY` 作为唯一完成条件；完成边沿后撤销 `PENABLE` 或进入下一笔 SETUP。可使用状态组合译码，或按下一阶段精确更新输出，但不能只改状态名称。
- 建议测试，未运行：分别覆盖 ready 常高、SETUP 高而 ACCESS 低、多个等待拍、完成后继续高，并用 scoreboard 断言“一次请求恰好一次总线完成”。

### F05 P1 APB 主机在取消选中后才采读数据

- 位置：[Bagu/AMBA_Bus/apb_master.v:L135-L142](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/AMBA_Bus/apb_master.v#L135-L142)，配对从机 [Bagu/AMBA_Bus/apb_slave.v:L56-L60](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/AMBA_Bus/apb_slave.v#L56-L60)。
- 触发：修复端口连接及其他阻断项后读取非零值；从机在未选中时不保持读数据，这是本目录从机的行为。
- 原因和后果：DONE 沿已将 `PSEL` 清零，下一状态 WAIT 才采 `i_PRDATA`。此时本目录从机的组合读输出已为 0，因此主机返回 0。协议只要求完成 ACCESS 时读数据有效，不能依赖其在事务结束后继续保持。
- 修复：在实际 `PSEL && PENABLE && PREADY && !PWRITE` 完成边沿采样读数据，并使完成通知与已锁存数据的有效性一致。
- 建议测试，未运行：从机仅在被选中的读 ACCESS 返回 `32'h12345678`，结束立即清零；检查主机仍返回该值。

### F06 P1 原版同步 FIFO 在空或满时同时读写导致占用计数失步

- 位置：[Bagu/sync_fifo/sync_fifo.v:L25-L49](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/sync_fifo/sync_fifo.v#L25-L49)、[Bagu/sync_fifo/sync_fifo.v:L61-L86](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/sync_fifo/sync_fifo.v#L61-L86)。
- 触发和后果：空时 `i_wren=i_rden=1`，写指针和 RAM 实际前进，但计数不加、empty 不解除；满时两个请求同为 1，读指针实际前进，但计数不减、full 不解除。持续同一请求组合可锁住边界，失步后占用判定不再可靠；不能解释为任何后续请求都无法改变标志。
- 原因：数据通路使用各自门控后的有效操作，计数逻辑却同时检查原始请求，漏掉“一方被拒绝、另一方接受”的情况。
- 修复：统一 `w_en=i_wren&&!full`、`r_en=i_rden&&!empty` 更新数据、指针及计数；推荐版 [Bagu/sync_fifo/sync_fifo_new.v:L21-L62](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/sync_fifo/sync_fifo_new.v#L21-L62) 已采用这一方法。
- 归类限定：这是**仍存在的已知教学缺陷**；[Bagu/sync_fifo/README.md:L7-L10](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/sync_fifo/README.md#L7-L10) 已写明原版保留作复盘、不要直接例化，不应据此说推荐版同样失败。
- 建议测试，未运行：绕过 TB 对请求的保护，在 empty/full 两个边界强制两个原始请求同时为 1，以参考队列检查计数、指针和下一笔读值。

### F07 P2 单口 RAM 的复位循环漏掉地址 15

- 位置：[Bagu/single_ram/single_ram.v:L9-L24](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/single_ram/single_ram.v#L9-L24)。
- 触发：复位后直接读 15，或先向 15 写入非零值、重新复位、再读 15。
- 原因和后果：数组为 `[0:15]`，循环条件却是 `i<15`，仅清零 0 至 14。地址 15 保持上次数据；初次仿真未写时通常为 X，和其余地址的复位行为不一致。
- 修复：若规格要求全清零，循环上限改为 16；若面向 BRAM，另行选择不复位阵列、靠有效性管理的架构，并同步修改接口契约，不能只删复位而不说明。
- 建议测试，未运行：对全部 16 个地址写不同非零值后复位，逐地址读回校验。

### F08 P2 同步 FIFO TB 将复位期间的请求算成成功写入

- 位置：[Bagu/sync_fifo/sync_fifo_tb.v:L45-L46](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/sync_fifo/sync_fifo_tb.v#L45-L46)、[Bagu/sync_fifo/sync_fifo_tb.v:L103-L137](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/sync_fifo/sync_fifo_tb.v#L103-L137)。
- 触发：现有默认激励即会出现；复位期间 count 清零，`o_full=0`，故 `i_wren=1`。
- 原因和后果：`wr_cnt` 每个时钟按请求递增，却未用复位门控或清零，而 DUT 的指针/占用仍在复位。打印的 `written == read + in_fifo` 从一开始就失真。结尾只 `$display`，即使不等也不报失败；最后一个 posedge 与 NBA 更新同刻结束还会增加对账时序歧义。
- 修复：参考模型只在复位释放且实际接受传输时计数，复位同步清空队列/计数；在 NBA 之后检查读回数据和占用，不一致用 `$fatal`。保留 DDS 波形演示，但不能把它当作完整自检回归。
- 建议测试，未运行：初始复位和中途复位均检查账目归零；比较数据顺序而不只比较笔数；注入 F06 的边界请求证明 TB 能捕获它。

## 二 条件风险 参数边界和复用前提

### R01 P2 APB 从机在等待拍也写存储 应明确提交点

- 位置：[Bagu/AMBA_Bus/apb_slave.v:L24-L53](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/AMBA_Bus/apb_slave.v#L24-L53)。
- 现状：写条件为 `PSEL && PENABLE && PWRITE`，未含 `PREADY`，在等待期间已写入且可能重复写相同字节。
- 限定：对当前纯 RAM，从机等待时合法主机必须保持地址、数据和 strobe 稳定，重复写同一值不会改变最终结果；复位又会清阵列。因此**没有证明合法默认 RAM 访问必然因此损坏**，不能将“等待中撤销请求”当成合法 APB 反例。若以后改为计数器/FIFO/有副作用寄存器，或允许其他端口观察尚未完成的写，这种提前执行才会产生可见问题。
- 建议：将存储提交统一限定在 `PSEL && PENABLE && PREADY && PWRITE`，保持每事务一次的可扩展规则。
- 建议检查，未运行：等待拍内不产生提交事件，完成沿只提交一次；若加入有副作用寄存器，检查等待周期不重复触发。

### R02 P2 FIFO 深度并非任意正整数 小深度也需特化

- 位置：[Bagu/sync_fifo/sync_fifo.v:L22-L38](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/sync_fifo/sync_fifo.v#L22-L38)、[Bagu/sync_fifo/sync_fifo_new.v:L15-L39](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/sync_fifo/sync_fifo_new.v#L15-L39)、[Bagu/async_fifo/async_fifo.v:L15-L36](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/async_fifo/async_fifo.v#L15-L36)、[Bagu/async_fifo/async_fifo.v:L61-L74](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/async_fifo/async_fifo.v#L61-L74)。
- 触发及后果：同步 FIFO 设深度 10 时，4 位指针自然按 16 回绕。写满 10 项、读一项、再写时访问数组地址 10，越过 `[0:9]`。异步 FIFO 的 Gray 高两位取反判满同样基于 2 的幂环，深度 10 时会按 16 项距离判满，不能匹配十项存储。
- 小深度：同步深度 1 会产生 `[-1:0]` 指针且继续递增；异步深度 2 在满比较产生 `[-1:0]` 尾切片，存在非法/越界选择。不是所有 2 的幂都已经被当前写法正确支持。
- 修复：同步 FIFO 可显式到 `DEPTH-1` 回零并特化深度 1；或先约束为 2 的幂且至少 2。当前异步写法建议限制为 2 的幂且至少 4，若需深度 2 则特化切片。宽度参数必须大于零，配置不合法时应清楚拒绝。
- 建议测试，未运行：深度 1、2、4、10、16，合法配置至少回绕两轮，非法配置在展开时给出错误。

### R03 P1 组合 Gray 直接跨域不能保证指针或多位状态一致

- 位置：[Bagu/async_fifo/async_fifo.v:L15-L63](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/async_fifo/async_fifo.v#L15-L63)、[Bagu/gray_cdc/gray_cdc.v:L2-L16](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/gray_cdc/gray_cdc.v#L2-L16)。
- 触发：二进制多位进位如 3→4、7→8 时，源寄存器 Q 与 XOR 路径延迟不同；组合 Gray 可能短暂出现错误码，被异步目的沿采中。稳定端点只差一位，不代表转换过程无毛刺。两级同步不能修复错误多位组合。
- 后果：异步 FIFO 可能失去“仅保守地假空/假满”的保证，导致覆盖未读项或读无效项；`gray_cdc` 可能输出不一致状态。这里是**物理条件风险，没有观测到硬件亚稳态或宣称每次必错**。
- `gray_cdc` 还有适用条件：`clka` 未使用，输入没有源域锁存；任意二进制跳变不能靠 Gray 编码获得一致性。例如 0→2 编码为 0000→0011，端点本身就变两位。须限制相邻计数变化/保持；若传任意 payload，应选握手或 FIFO。目的端跳过若干中间计数值不自动是错误，状态快照不等于无损事件队列。
- 修复：在源域寄存对应下一值的 Gray 编码，只有寄存器输出跨域；补同步器识别属性、Gray 总线最大延迟/偏斜约束和 CDC 检查。异步 FIFO 的本地二进制与 Gray 必须表示同一接受事件后的指针。
- 建议验证，未运行：检查源 Gray 更新 `onehot0`、进位与回绕、不同频比/相位及队列顺序；另做 CDC/实现后偏斜检查。无延迟 RTL 仿真不能证明没有组合毛刺。
- 一手参考：[AMD XPM_CDC_GRAY](https://docs.amd.com/r/2022.2-English/ug953-vivado-7series-libraries/XPM_CDC_GRAY) 与 [AMD 总线偏斜约束](https://docs.amd.com/r/2024.2-English/ug903-vivado-using-constraints/About-Bus-Skew-Constraints?contentId=kXqymQdxWW597oxcQ4ClQw)，仅作为结构与约束依据，不表示项目指定了 AMD 器件。

### R04 P2 固定五拍脉冲展宽缺少速率契约且 OR 输出未经注册

- 位置：[Bagu/pulse_cdc/pulse_cdc.v:L8-L35](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/pulse_cdc/pulse_cdc.v#L8-L35)。
- 可确定推导的条件反例：源周期 10ns，事件使展宽电平在 `[10,60)ns` 为高，目的上升沿为 5、65ns 时完全漏采。两个源事件相距不超过五拍，其展宽窗口相接或重叠，目的上升沿检测只报一次；即使间隔超过五拍，低窗口若没被目的时钟采到，仍会合并。
- 额外物理风险：单个 1 在移位寄存器中移动时，多个 Q 先后变化，`|pulse_r` 可能有短低毛刺；若被目的域采到，可使一个事件产生额外上升沿。两级同步前的组合 OR 不宜当成无毛刺电平。
- 限定：在约定的时钟比、最小高/低窗口、事件间隔下可作教学例；当前没有说明这些条件。若上层要求无损中断/事件传递，应将此项升为 P1。
- 修复：受限速率时明确 `pulse_in` 属于源域、能被源采到、目的能可靠采到高和低窗口，并把展宽输出注册为单一源寄存器；无损场景用有 busy/ready 的闭环，突发场景用计数器或 FIFO。只改成 toggle 仍需事件间隔或反馈。
- 建议验证，未运行：快慢时钟互换、目的停钟、事件间隔 1/4/5/6 拍、相位扫描、输入输出事件计数，以及组合毛刺/CDC 实现检查。

### R05 P2 dmux 需要完整的数据保持和 valid 采样契约

- 位置：[Bagu/dmux/dmux.v:L2-L24](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/dmux/dmux.v#L2-L24)。
- 触发：短 `valid` 脉冲落在目的沿之间会漏采；`valid` 高时连续换数据，或原始 valid 拉低后立即换数据，目的域仍可能因同步延迟继续采样原始多位 `data_in`。尤其下降同步的两拍尾部仍可接收无效新数据。
- 后果：没有一事件一输出或多位字一致性的保证；物理采样还可能遇到总线撕裂。`clk_src` 未使用，没有源域保持寄存器或应答。
- 限定：这是控制同步、裸数据采样的受限 MCP 结构；若外部保证完整稳定窗口和足够事件间隔并配约束，可正确使用，不能一概宣称此类结构错误。对每个数据位分别加两拍也不能解决字一致性。
- 修复：明确电平使能语义和从首次采样前一直到同步使能完全撤销的数据保持窗口；更通用的用法采用源保持寄存器加 req/ack、目的一次采样，或异步 FIFO。
- 建议验证，未运行：短脉冲、撤销 valid 立即换字、持续 valid 时换字、不同频比/相位、传输中复位，以模型比较输出次数和数据。

### R06 P1 教学时钟切换器不能直接作为硬件无毛刺保证

- 位置：[Bagu/clk_switch/clk_switch.v:L13-L29](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/clk_switch/clk_switch.v#L13-L29)、[Bagu/clk_switch/无毛刺时钟切换.md:L49-L61](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/clk_switch/%E6%97%A0%E6%AF%9B%E5%88%BA%E6%97%B6%E9%92%9F%E5%88%87%E6%8D%A2.md#L49-L61)。
- 条件风险：异步 `sel` 与对方时钟域 Q 直接进入单级下降沿 DFF，该 Q 又直接门控时钟。如果控制/反馈靠近下降沿使 DFF 亚稳，且在低相位内没解析完，使能可能在高相位变化，造成残缺脉冲。下降沿更新提供解析窗口，但不等于无条件保证；没有器件、频率和可靠性目标，不能断言准静态反馈的 MTBF 足够。
- 已知限制：文档已承认单级简化、无复位和旧时钟停振可能卡住。两钟持续运行、sel 稳定的理想数字模型中，先关后开的思路成立。无复位导致启动未知，但不等于永远 X：稳定 sel 会先关闭未选侧再使能选中侧。
- 修复：FPGA 优先用目标器件的专用 glitch-free clock mux/control primitive；ASIC 用验证过的时钟切换单元或协议，并补时钟、互斥、脉宽与实现约束。不要只同步 sel 到一个域就认为问题已解决。若新增异步复位，须考虑高电平时清门截断时钟以及下游隔离。
- 建议验证，未运行：两向切换、贴近下降沿、非整数频比、快速反切、旧钟停振和启动；检查输出高/低脉宽、互斥及完成。物理保证需要 CDC/STA/器件级分析。

### R07 P2 各时钟域复位释放及同步器约束属于未明确的集成前提

- 位置：[Bagu/async_fifo/async_fifo.v:L17-L57](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/async_fifo/async_fifo.v#L17-L57)、[Bagu/pulse_cdc/pulse_cdc.v:L10-L31](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/pulse_cdc/pulse_cdc.v#L10-L31)、[Bagu/handshake/top.v:L13-L28](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/handshake/top.v#L13-L28)、[Bagu/async_ram/async_ram.v:L16-L35](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/async_ram/async_ram.v#L16-L35)；单时钟异步复位模块也需遵守相同原则。
- 触发和后果：若 `rst_n` 是真正异步外部信号，在任一域时钟沿附近释放可违反 recovery/removal，造成指针、计数器、握手启动状态不一致。顶层若已保证安全释放，此项只是接口必须记录的前提，不能判定它必然出错。
- 修复：每个独立时钟域分别异步断言、同步释放，并约定共同清空、在途事务作废及双域就绪前禁止传输。[Bagu/Async_rst/async_reset.v:L8-L18](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/Async_rst/async_reset.v#L8-L18) 已提供正确的基本两级释放结构；应结合具体实例使用。同步器属性、物理靠近、数据保持路径和复位树时序仍需目标工具验证。
- 限定：Bagu 没有 XDC/SDC 不证明整仓库或外部集成没有约束；不要把“复位由同一根线驱动”当作下游一定同时安全释放。
- 建议验证，未运行：复位随机相位、任一时钟停止后释放、req/ack 各阶段或 FIFO 非空时共同复位；检查首笔事务和 RDC/recovery/removal/最小复位脉宽。

### R08 P2 RAM 阵列清零和双时钟同址碰撞需按目标实现定义

- 整阵列异步清零位置：[Bagu/AMBA_Bus/apb_slave.v:L42-L46](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/AMBA_Bus/apb_slave.v#L42-L46)、[Bagu/async_fifo/async_ram.v:L18-L24](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/async_fifo/async_ram.v#L18-L24)、[Bagu/async_ram/async_ram.v:L14-L20](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/async_ram/async_ram.v#L14-L20)、[Bagu/single_ram/single_ram.v:L9-L16](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/single_ram/single_ram.v#L9-L16)、[Bagu/single_ram_rdfst/single_ram_rdfst.v:L12-L20](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/single_ram_rdfst/single_ram_rdfst.v#L12-L20)、[Bagu/single_ram_rdfst/single_ram_wrfst.v:L12-L20](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/single_ram_rdfst/single_ram_wrfst.v#L12-L20)、[Bagu/sync_fifo/sync_fifo.v:L55-L62](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/sync_fifo/sync_fifo.v#L55-L62)。
- 触发及后果：如果期望映射为常规 FPGA 块 RAM，运行时异步清全部存储单元的语义通常不匹配原语，可能退化为寄存器/逻辑、增加扇出和时序代价。16×8 教学阵列可以有意如此；APB 的 1024×32 阵列扩大了资源影响。**这不是“已经综合失败”或“不可综合”的结论。**
- 修复：FIFO 可只复位指针/标志/输出；独立 RAM 若要求复位后任意地址读零，应采用有效位或初始化状态机，不能直接删除阵列复位而改变语义。使用目标 RAM 模板并检查资源报告。[Altera RAM reset 指南](https://docs.altera.com/r/docs/683323/18.1/intel-quartus-prime-standard-edition-user-guide-design-recommendations/avoid-unsupported-reset-and-control-conditions)
- 同址碰撞位置：[Bagu/async_ram/async_ram.v:L22-L35](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/async_ram/async_ram.v#L22-L35)、[Bagu/async_fifo/async_ram.v:L26-L39](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/async_fifo/async_ram.v#L26-L39)。当独立读写时钟近同时访问同址，RTL 同时刻 NBA 读到旧值并不能保证物理独立时钟 RAM 也 read-first；若上层没有所有权协议，应禁止该窗口或用目标原语明确的碰撞处理。合法 FIFO 控制通常可避免该冲突，不把此项算作默认 FIFO 必现错误。[AMD 地址碰撞说明](https://docs.amd.com/r/en-US/ug573-ultrascale-memory-resources/Address-Collision)
- 建议验证，未运行：资源/原语推断、全地址复位语义、同址冲突环境断言、独立时钟相位扫描和目标 RAM 模型检查。

### R09 P2 序列检测 flag 是命中状态电平 不是无条件单拍事件

- 位置：[Bagu/sequence_detect/seq_det.v:L27-L29](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/sequence_detect/seq_det.v#L27-L29)、[Bagu/sequence_detect/seq_det.v:L73-L98](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/sequence_detect/seq_det.v#L73-L98)；文档 [Bagu/sequence_detect/README.md:L7-L22](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/sequence_detect/README.md#L7-L22)。
- 条件：接受有效位 `10110` 后进入 S5，再让 `din_valid=0` 连续三拍，状态保持，flag 也一直为 1。如果下游每拍 flag=1 计一次，就重复计数。
- 限定：代码明示“S5 期间为高”，README 说明无效拍保持，因此这是目前合理的 Moore 电平语义，**不是确定的状态机算法 bug**。S3→S2、S4→S1、S5→S3/IDLE 的重叠回退关系静态合理。
- 修复建议：文档先明确电平/事件契约；若要求脉冲，在接受最后有效位的边沿寄存一拍事件，例如原状态 S4 且 din_valid 且 !din。保留原状态机以继续匹配重叠前缀。
- 建议测试，未运行：`10110110` 两次重叠命中、各前缀插气泡、命中后暂停、部分匹配中复位。当前 TB 的 `101101` 一次命中不足以证明重叠双命中。

### R10 P2 DDS 和测试参数需要合法范围声明

- 位置：[Bagu/sync_fifo/dds_sine.v:L13-L45](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/sync_fifo/dds_sine.v#L13-L45)。
- 条件：`OUT_W>32` 时 `$rtoi` 的 32 位有符号中间结果不能表示所需峰值，赋给更宽 ROM 不会恢复幅度；`PHASE_W<LUT_AW` 或 `LUT_AW<=0` 使相位切片不成立；`1<<LUT_AW` 也不能不受限制地扩展。
- 限定：默认 32/8/32 没有发现这种参数溢出；文件明确是 FIFO 的仿真激励，`initial/$sin` 不应单独算作 RTL 功能错误。但“工具支持 initial ROM”不等于保证支持所有 real/$sin 常量计算流程。
- 修复：声明并检查有效参数；需更宽输出时离线生成足够精度的定宽 ROM 常量。若上板使用，按实际综合器验证 ROM 初始化支持。
- 测试参数：[Bagu/sync_fifo/sync_fifo_tb.v:L79-L100](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/sync_fifo/sync_fifo_tb.v#L79-L100) 的计数器固定 9 位，`RD_START>511` 无法起读、`RD_DIV>512` 无法触发读取；按最大参数定宽并限制正值，当前默认 120/4 不受此项影响。
- 建议测试，未运行：默认峰值、零点、周期、enable 暂停连续性、FCW 切换；非法宽度/节奏参数清晰拒绝。

### R11 P2 APB 用户侧请求接受时刻和负载保持要求需明确

- 位置：[Bagu/AMBA_Bus/apb_master.v:L5-L11](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/AMBA_Bus/apb_master.v#L5-L11)、[Bagu/AMBA_Bus/apb_master.v:L58-L62](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/AMBA_Bus/apb_master.v#L58-L62)、[Bagu/AMBA_Bus/apb_master.v:L115-L128](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/AMBA_Bus/apb_master.v#L115-L128)。
- 条件：`i_en/i_write` 在 IDLE 沿决定是否发起及方向，地址和写数据却在后一拍 WRITE/READ 才采。如果调用方把 i_en 当作单拍请求，并在该沿后改变地址/数据，会发送后一拍的负载。非 IDLE 时的短请求也没有队列或 ready/busy 信号告知接受结果。
- 限定：没有用户侧协议说明，因此不能断言所有调用方必错；若上游按实际采样时刻保持并只在空闲发起，可以满足当前行为。
- 修复与建议测试，未运行：优先在统一接受沿锁存方向、地址、数据、strobe，公开 ready/busy 或明确请求保持协议；检查单拍请求后立即改变负载、忙时请求及连续请求，验证接收数量与负载对应。

## 三 测试工程与已有 Markdown 的准确性

### T01 P2 八个 TB 都缺少自动功能判错 时钟回切测试提前结束

- 八个 TB 的全文均已阅读，均未建立 assertions/scoreboard/`$fatal` 级别的自动功能判定。波形输出、打印样本、正常 `$finish` 都不能等同于功能通过。
- [Bagu/clk_switch/tb_clk_switch.v:L32-L38](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/clk_switch/tb_clk_switch.v#L32-L38) 在 `sel=0` 后立即 `$finish`，没有等待后续下降沿完成回切；应等待恢复 clk0 及若干输出周期后检查两向切换。
- [Bagu/sync_fifo/sync_fifo_tb.v:L45-L46](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/sync_fifo/sync_fifo_tb.v#L45-L46) 与 [Bagu/sync_fifo/sync_fifo_tb.v:L100-L110](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/sync_fifo/sync_fifo_tb.v#L100-L110) 用 `!full/!empty` 预先屏蔽请求，无法触发 F06 的“原始请求同时高、其中一方被拒绝”边界。仅样本计数也发现不了等数量错序/重复。
- [Bagu/sequence_detect/seq_det_tb.v:L30-L55](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/sequence_detect/seq_det_tb.v#L30-L55) 只有短序列；[Bagu/single_ram/single_ram_tb.v:L31-L71](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/single_ram/single_ram_tb.v#L31-L71) 是随机激励和波形，没有全地址 shadow memory；[Bagu/handshake/top_tb.v:L32-L50](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/handshake/top_tb.v#L32-L50) 没有在 req/ack 各阶段复位及逐事务比对。
- 建议：给每类模块建立参考模型、定向边界、超时和失败退出；将“产生波形”和“自检通过”分开记录。建议测试见后面的矩阵，全部未执行。

### T02 P3 测试时钟有整数除法截断 时间尺度和驱动时刻需统一

- 确定配置偏差：[Bagu/dmux/dmux_tb.v:L7-L35](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/dmux/dmux_tb.v#L7-L35) 的 `PERIOD2=5`、整数 `/2` 得 2，在 `1ps/1ps` 下实际周期为 4ps；[Bagu/handshake/top_tb.v:L1-L29](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/handshake/top_tb.v#L1-L29) 同样把 A 周期 5ps 变为 4ps，B 为 10ps，实际频比为 2.5 而非 2。
- 复位/输入 active-region 竞态：[Bagu/sync_fifo/sync_fifo_tb.v:L121-L130](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/sync_fifo/sync_fifo_tb.v#L121-L130)、[Bagu/sync_fifo/dds_sine_tb.v:L19-L24](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/sync_fifo/dds_sine_tb.v#L19-L24)、[Bagu/single_ram/single_ram_tb.v:L31-L50](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/single_ram/single_ram_tb.v#L31-L50) 在 DUT 采样 posedge 后用阻塞赋值释放 reset、切换使能或 FCW，精确采旧/新值的拍号可能受调度顺序影响。握手和复位 TB 也有沿上驱动，见 [Bagu/handshake/top_tb.v:L32-L41](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/handshake/top_tb.v#L32-L41)、[Bagu/Async_rst/tb_async_reset.v:L27-L34](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/Async_rst/tb_async_reset.v#L27-L34)。
- 修复：使用可表示的半周期和足够细的 timeprecision；仅改 `/2.0` 而保持 1ps 精度仍不能精确表示 2.5ps。统一下降沿或 clocking block 驱动，NBA 后比较输出；TB 自检实际时钟周期。`seq_det_tb` 未声明时间单位，建议补齐以消除工具/合编环境差异。

### T03 P2 同名模块需要显式文件集避免选错练习版本

- 位置：[Bagu/sync_fifo/sync_fifo.v:L1-L5](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/sync_fifo/sync_fifo.v#L1-L5) 与 [Bagu/sync_fifo/sync_fifo_new.v:L1-L5](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/sync_fifo/sync_fifo_new.v#L1-L5) 都声明 `module sync_fifo`；[Bagu/async_fifo/async_ram.v:L1-L4](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/async_fifo/async_ram.v#L1-L4) 与 [Bagu/async_ram/async_ram.v:L1-L13](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/async_ram/async_ram.v#L1-L13) 都声明 `module async_ram`。
- 触发和后果：同步 FIFO 目录通配编译或递归包含 Bagu 时常见工具会报重复模块定义；文件选择不清楚还可能误用旧版 FIFO，或用不支持参数覆盖的固定 RAM 替换参数版。显式隔离的单模块文件集不会触发，不能笼统说仓库一定无法编译。
- 修复：增加每个示例的明确 filelist 和 testbench 顶层；推荐版和复盘版分别构建。未来若改名，应同步全部例化和说明。本轮不执行编译。

### D01 P2 复位笔记 removal 定义需要修正

- 位置：[Bagu/Async_rst/异步复位同步释放.md:L18-L23](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/Async_rst/%E5%BC%82%E6%AD%A5%E5%A4%8D%E4%BD%8D%E5%90%8C%E6%AD%A5%E9%87%8A%E6%94%BE.md#L18-L23)。第 21 行将 removal 关联到“断言（下降沿）”。对这里低有效异步复位，recovery/removal 都围绕**释放上升沿**与有效时钟沿的关系；removal 要求有效时钟沿后复位仍保持有效一段时间，之后才释放。错误会影响读时序报告和复位设计判断，不是 `async_reset.v` 结构错误。[官方 recovery/removal 说明](https://docs.altera.com/r/docs/683539/25.1.1/an-917-reset-design-techniques-for-hyperflex-architecture-fpgas/recovery-and-removal-checks)
- 修复：明确释放沿的前后禁止窗口，并给出低有效复位时序图。建议人工逐条核对说明和波形，此轮未进行动态验证。

### D02 P3 其余三份笔记及示例描述应与当前源码和适用条件同步

| 文档位置 | 当前不准确或需要限定之处 | 建议修订 |
|---|---|---|
| [Bagu/Async_rst/异步复位同步释放.md:L72-L77](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/Async_rst/%E5%BC%82%E6%AD%A5%E5%A4%8D%E4%BD%8D%E5%90%8C%E6%AD%A5%E9%87%8A%E6%94%BE.md#L72-L77) | “同域内一起释放”忽略复位树时序；TB 实际在 posedge 直接断言，随后 `PERIOD/4` 整数延时 2ps 释放，不是文字所述的偏移断言 | 写明实现约束，准确区分断言与释放时刻；两级降低风险并非消灭全部亚稳态概率 |
| [Bagu/clk_switch/无毛刺时钟切换.md:L39-L45](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/clk_switch/%E6%97%A0%E6%AF%9B%E5%88%BA%E6%97%B6%E9%92%9F%E5%88%87%E6%8D%A2.md#L39-L45)、[Bagu/clk_switch/无毛刺时钟切换.md:L58-L69](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/clk_switch/%E6%97%A0%E6%AF%9B%E5%88%BA%E6%97%B6%E9%92%9F%E5%88%87%E6%8D%A2.md#L58-L69) | 切换延迟不是固定“旧低相位+新低相位”；准静态单级反馈不能无数据保证 MTBF；TB 实为 10ps/20ps 而非 10ns/20ns，且未观察完整回切 | 延迟拆为等旧下降沿、等新下降沿、新低相位；列出运行条件，修正文档单位和覆盖表述 |
| [Bagu/sequence_detect/README.md:L7-L23](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/sequence_detect/README.md#L7-L23) | 历史“仿真通过”本轮没有复跑；“Moore 无毛刺、比 Mealy 晚一拍”过于绝对 | 保留历史记录但注明验证版本/方式；本例第五个有效位后进入 S5 即拉 flag，并无额外输出寄存器；延迟比较要说明观察时刻、组合/寄存 Mealy 及实现编码 |
| [Bagu/sync_fifo/README.md:L7-L10](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/sync_fifo/README.md#L7-L10)、[Bagu/sync_fifo/README.md:L69-L88](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/sync_fifo/README.md#L69-L88)、[Bagu/sync_fifo/README.md:L95-L105](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/sync_fifo/README.md#L95-L105) | 声称当前旧版读指针错误和未用死代码，但源码已用 `r_rd_ptr`，也无所述 `r_fifo_number` 声明；“永久死锁”需限定持续请求模式；Gray+2FF“绝不丢数据”缺前提 | 将已修内容标为历史并链接当时提交；只把 F06 列为现存旧版计数问题；补源注册、合法深度、复位、偏斜和速率前提 |

## 四 已校核且不应误报的设计选择

1. `async_reset` 两级异步断言/同步释放基本语义正确；`seq_det` 使用同步低有效复位与 README 一致，不能因为缺 `negedge rst_n` 就判错。
2. `handshake/driver.v` 在发 req 同拍锁存 `data_tx`，在四相应答期间保持；`receiver.v` 同步 req 后再采数据、保持 ack 到 req 撤销。默认理想数字时序下闭环成立，不是因为总线没逐位两拍就错。实际 bundled-data 路径仍须稳定时间/最大延迟约束。它是空闲计数到阈值后自动采样的教学接口，没有输入 valid/ready 或输出 valid，不承诺捕获每次外部 data 变化。对应 [Bagu/handshake/driver.v:L23-L57](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/handshake/driver.v#L23-L57)、[Bagu/handshake/receiver.v:L11-L42](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/handshake/receiver.v#L11-L42)。
3. `sync_fifo_new` 默认参数的写/读/计数采用同一接受判据；空时拒绝读、满时拒绝写，属于 README 明确选定的保守策略。没有要求满时交换或空时旁路的规格，不能把它们缺失算成 bug。其不复位 RAM 也合理；复位时写 RAM 地址 0 不会自动造成可见脏数据，因为占用/指针被清零、后续有效写覆盖后才允许读。
4. 异步 FIFO 使用当前 Gray 组合判空满，不自动等于“晚一拍溢出”，因为标志在指针更新后立即重算。应修的是源 Gray 跨域毛刺与实现约束。`.ADDR_WIDTH(FIFO_DEPTH)` 符合其 RAM 中“深度”的实际参数定义，只是命名容易误会。
5. `single_ram` 写时保持输出、读时寄存输出是合理 no-change 语义。`single_ram_rdfst` 同钟两个 NBA 过程自然读旧值；`single_ram_wrfst` 同址有效读写时旁路输入，write-first 语义合理。独立读写地址意味着后两者接口更像一写一读简单双口，名称可改进，但不是功能错误。
6. `gray_cdc.dout` 目前输出 Gray 码，例如二进制 2 对应输出 3；若要求透明二进制输出需解码，但没有调用方或说明足以确定原意，因此不定为遗漏解码的确定缺陷。无复位意味着启动若干目的采样前不能认为输出有效，应写清启动契约。
7. DDS 组合输出和相位更新在 FIFO 同一沿分别读取旧样本、推进相位，按当前共同使能的消费方式静态对齐，没有发现默认固有的一拍错位。

## 五 逐文件全覆盖清单

“全文已查”表示接口、全部过程/语句或整份文档已读，**不表示测试通过**。下列 32 行与基线递归树逐项一致，无未读文件。

| 文件 | 用途 | 审查状态与结论 |
|---|---|---|
| [Bagu/AMBA_Bus/apb_master.v](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/AMBA_Bus/apb_master.v) | APB 主机及用户请求接口 | 全文已查；F01/F03/F04/F05/R11，输出、strobe、握手与请求/读数时点 |
| [Bagu/AMBA_Bus/apb_slave.v](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/AMBA_Bus/apb_slave.v) | 1024×32 APB 存储从机、字节写和等待 | 全文已查；F02/R01/R08，等待计数及存储提交/实现 |
| [Bagu/Async_rst/async_reset.v](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/Async_rst/async_reset.v) | 两级异步断言同步释放 | 全文已查；基本结构合理，R07 实现前提 |
| [Bagu/Async_rst/tb_async_reset.v](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/Async_rst/tb_async_reset.v) | 复位波形激励 | 全文已查；T01/T02，缺自检与沿上复位驱动 |
| [Bagu/Async_rst/异步复位同步释放.md](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/Async_rst/%E5%BC%82%E6%AD%A5%E5%A4%8D%E4%BD%8D%E5%90%8C%E6%AD%A5%E9%87%8A%E6%94%BE.md) | 复位原理与问答 | 全文已查；D01/D02，removal 与示例描述 |
| [Bagu/async_fifo/async_fifo.v](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/async_fifo/async_fifo.v) | Gray 指针双时钟 FIFO | 全文已查；R02/R03/R07，深度、CDC、释放条件 |
| [Bagu/async_fifo/async_ram.v](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/async_fifo/async_ram.v) | 参数化双时钟同步读写 RAM | 全文已查；R08/T03，阵列清零、碰撞、模块重名 |
| [Bagu/async_ram/async_ram.v](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/async_ram/async_ram.v) | 固定16×8双时钟 RAM | 全文已查；R07/R08/T03，碰撞/释放及重名 |
| [Bagu/clk_switch/clk_switch.v](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/clk_switch/clk_switch.v) | 交叉互锁下降沿时钟切换 | 全文已查；R06，物理门控/启动/停钟限制 |
| [Bagu/clk_switch/tb_clk_switch.v](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/clk_switch/tb_clk_switch.v) | 两向切换激励 | 全文已查；T01，回切立即结束、无自检 |
| [Bagu/clk_switch/无毛刺时钟切换.md](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/clk_switch/%E6%97%A0%E6%AF%9B%E5%88%BA%E6%97%B6%E9%92%9F%E5%88%87%E6%8D%A2.md) | 切换原理和教学限制 | 全文已查；R06/D02，MTBF、延迟和单位 |
| [Bagu/dmux/dmux.v](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/dmux/dmux.v) | 同步 valid 后采多位总线 | 全文已查；R05/R07，保持窗口与短控制脉冲 |
| [Bagu/dmux/dmux_tb.v](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/dmux/dmux_tb.v) | valid 电平与换字激励 | 全文已查；T01/T02，实际目的周期4ps、无模型 |
| [Bagu/gray_cdc/gray_cdc.v](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/gray_cdc/gray_cdc.v) | 二进制转 Gray 后双拍采样 | 全文已查；R03，源注册/输入序列/输出编码契约 |
| [Bagu/handshake/driver.v](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/handshake/driver.v) | 源端周期采样、req/ack 发送 | 全文已查；四相与保持合理，R07及采样接口限制 |
| [Bagu/handshake/receiver.v](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/handshake/receiver.v) | 同步请求、锁数据、返回应答 | 全文已查；数字协议合理，R07与bundled-data时序 |
| [Bagu/handshake/top.v](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/handshake/top.v) | 双时钟握手连线 | 全文已查；连接位宽一致，R07共同复位契约 |
| [Bagu/handshake/top_tb.v](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/handshake/top_tb.v) | 双时钟数据刺激 | 全文已查；T01/T02，A实际周期4ps、缺自检 |
| [Bagu/pulse_cdc/pulse_cdc.v](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/pulse_cdc/pulse_cdc.v) | 五拍展宽、同步、上升沿检测 | 全文已查；R04/R07，漏采/合并/OR毛刺 |
| [Bagu/sequence_detect/README.md](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/sequence_detect/README.md) | 10110重叠检测设计说明 | 全文已查；R09/D02，flag语义与历史验证限定 |
| [Bagu/sequence_detect/seq_det.v](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/sequence_detect/seq_det.v) | 六态Moore重叠检测FSM | 全文已查；回退合理，R09命中暂停电平 |
| [Bagu/sequence_detect/seq_det_tb.v](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/sequence_detect/seq_det_tb.v) | 短序列和波形激励 | 全文已查；T01/T02，无自检、未测双重叠命中 |
| [Bagu/single_ram/single_ram.v](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/single_ram/single_ram.v) | 单地址16×8同步读写 | 全文已查；F07/R08，复位末地址漏清 |
| [Bagu/single_ram/single_ram_tb.v](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/single_ram/single_ram_tb.v) | 随机地址/数据RAM激励 | 全文已查；T01/T02，无shadow memory及沿上驱动 |
| [Bagu/single_ram_rdfst/single_ram_rdfst.v](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/single_ram_rdfst/single_ram_rdfst.v) | 同钟一写一读 read-first | 全文已查；NBA旧值语义合理，R08 |
| [Bagu/single_ram_rdfst/single_ram_wrfst.v](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/single_ram_rdfst/single_ram_wrfst.v) | 同钟一写一读 write-first旁路 | 全文已查；同址旁路合理，R08 |
| [Bagu/sync_fifo/README.md](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/sync_fifo/README.md) | 推荐版契约和旧版复盘 | 全文已查；D02，部分历史缺陷已不对应当前源码 |
| [Bagu/sync_fifo/dds_sine.v](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/sync_fifo/dds_sine.v) | FIFO仿真用DDS样本源 | 全文已查；默认相位消费合理，R10宽度边界 |
| [Bagu/sync_fifo/dds_sine_tb.v](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/sync_fifo/dds_sine_tb.v) | 64样本DDS打印 | 全文已查；T01/T02，无数值自检与沿上复位 |
| [Bagu/sync_fifo/sync_fifo.v](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/sync_fifo/sync_fifo.v) | 保留作复盘的原版同步FIFO | 全文已查；F06/R02/R08/T03，不作为推荐版 |
| [Bagu/sync_fifo/sync_fifo_new.v](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/sync_fifo/sync_fifo_new.v) | 统一接受判据的推荐同步FIFO | 全文已查；默认计数逻辑合理，R02/T03 |
| [Bagu/sync_fifo/sync_fifo_tb.v](https://github.com/Lucian-prog/FPGA/blob/bd2a1df56e09af168c97522b341f412f814cec47/Bagu/sync_fifo/sync_fifo_tb.v) | DDS背压与FIFO占用演示 | 全文已查；F08/R10/T01/T02/T03，计数及覆盖 |

## 六 建议修复与验证顺序 全部尚未执行

1. **先打通 APB 基本功能**：修输出连接和等待计数，再一并修 strobe、阶段对齐和握手沿取数。否则最先发现的断路会遮蔽后续问题，逐项“看起来修好”不代表事务已正确。
2. **明确复用接口契约**：FIFO 合法深度、Gray 输入变化方式、pulse 速率/是否无损、dmux 数据保持、seq_det 的 flag 含义、握手是采样还是交易接口。
3. **处理真实硬件风险**：源域注册 CDC 控制/Gray、每域复位释放、专用时钟切换资源、MCP/Gray 物理约束、RAM 映射与碰撞规则。不能只靠 RTL 波形签核。
4. **建立可失败的回归**：先补能够捕获已知反例的定向自检，再做随机；修正文档并为推荐版明确文件集。保留旧版教学 bug 时，应有清楚的预期失败用例，避免误用。

| 模块组 | 建议验证内容 | 现有 TB 顶层或缺口 | 本轮状态 |
|---|---|---|---|
| APB | ready常高、SETUP高/ACCESS低、多等待、恰好一次完成、非零回读、整字/字节写、等待中复位、连续请求、非法访问策略 | 本目录无 TB；须新增独立 master/slave模型和接口断言 | 未运行 |
| 异步 FIFO | 双向快慢比、异步相位、空满同时请求、两轮以上回绕、随机队列、共同复位/停钟、非法深度；另做CDC/约束检查 | 本目录无 TB | 未运行 |
| 同步 FIFO 与 DDS | 原始四种请求×占用0/1/D-1/D；逐项scoreboard、复位账目、完全排空、DDS暂停/改频/数值容差 | `sync_fifo_tb`、`dds_sine_tb`，每次只选一份 `sync_fifo` | 未运行 |
| reset synchronizer | 任意时刻异步断言、两拍释放、短脉宽、停钟释放、复位树时序 | 文件 `tb_async_reset.v` 的实际顶层为 `async_reset_tb` | 未运行 |
| clock switch | 完整往返、随机选择相位、非整数频比、启动/停钟、互斥、高低脉宽与完成超时 | `tb_clk_switch`；普通RTL模型不足以签核物理安全 | 未运行 |
| Gray 与 pulse CDC | Gray进位/回绕/非法跳值；展宽高低窗口、事件间隔、目的停钟与计数 | 两个目录均无 TB | 未运行 |
| dmux 与 handshake | 数据保持窗口、短valid、应答四相、一请求一次接收、在途复位、不同频率/相位 | `dmux_tb`、`handshake_top_tb` | 未运行 |
| 序列检测 | `10110110`双命中、气泡、命中暂停、回退、复位中止及有效位流模型 | `seq_det_tb` | 未运行 |
| RAM 家族 | 全地址预写复位、地址15、读写使能、read-first/write-first、输出保持；独立钟碰撞声明及目标原语检查 | `single_ram_tb`；async_ram及read/write-first无TB | 未运行 |

后续若获准执行测试，应遵守根说明，用实际 `module` 声明选择顶层、明确独立文件集；报告只建议用例，不声称已有脚本或测试结果。当前代码树没有可证明本轮动态正确性的产物。

## 七 结论边界与依据

- 32/32 文件阅读覆盖完整；静态审查可以确认明显接线、计数、边界与时序语义问题，不能穷尽所有输入空间或替代综合/时序/CDC签核。
- 未指定目标 FPGA、综合器/版本、物理约束、最大频率和顶层使用协议；器件相关内容因此明确按条件风险处理。
- 本报告没有重现或背书 README 中历史“仿真通过”的记录，没有声称编译通过、测试通过或可以直接上板。
- APB 协议依据为 [Arm AMBA APB Protocol Specification IHI 0024E](https://documentation-service.arm.com/static/63fe2c1356ea36189d4e79f3?token=)：SETUP 中 PREADY 可任意、低 PREADY 时需延长 ACCESS、PSTRB 表示有效写字节，PRDATA 应在有效完成时采样。其他器件说明已紧随对应风险引用，均为设计参考而非项目器件选择证明。
- 最终改动范围：本 Markdown 报告。RTL、TB、已有 Markdown 及其他仓库文件均未由本轮修改。
