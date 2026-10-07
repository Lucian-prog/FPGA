# FPGA 增量 RTL 静态审查：乘法器、仲裁器与 popcount（2026-10-07）

## 结论

本轮覆盖 **2 个新增源码提交、8 个新增 RTL 文件（271 行）及 2 个说明文件的变更**。在正整数参数、无符号乘法和下述接口契约内，**未发现可从源码确定的默认算术错误、流水数据/valid 错位、空泡串单或组合锁存器**。这只是静态推导结论，不是编译、仿真或实现验证通过。

需要在复用前明确的两个中等级别条件风险是：

1. 固定优先级两种实现的复位行为不一致；轮询仲裁复位只初始化搜索起点，并不屏蔽 grant。
2. 轮询仲裁每拍有 grant 就推进优先级，没有“真正接受/完成”的输入；只能直接用于每次授权都能被消费的逐拍仲裁，不能据此保证带背压或多拍事务的服务公平性。

乘法器核心连接合理：流水版各级使用前一级 valid；迭代版已经在注释中明确“mult_en 保持到完成，拉低即取消”。两者同名 mult_en 的语义不同，不能把迭代版当作单拍 start 接口，但这不是违反其现有注释的缺陷。固定优先级饥饿、组合 popcount、无符号运算、无输出背压均作为教学/使用契约讨论，不人为增加确定缺陷数量。

**本轮仅通过 GitHub 读取固定 SHA 的源码、差异、树与文档，进行离线 RTL 静态审查。没有编译、lint、仿真、综合、形式验证、CDC/RDC 工具检查、布局布线、STA 或上板测试，也没有执行 RTL-Agent 工具链。提交标题中的“verified”属于作者表述，本轮未复现或独立验证。**

## 一、版本、去重与文件覆盖

- 仓库：[Lucian-prog/FPGA](https://github.com/Lucian-prog/FPGA)，默认分支 `main`；分支清单返回的全部 1 个分支为 `main`。
- 上一已审源码基线：[`b611af4b8bb945684ba8c0e86720dadaa4f3ea3a`](https://github.com/Lucian-prog/FPGA/commit/b611af4b8bb945684ba8c0e86720dadaa4f3ea3a)。
- 上一报告提交：[`92b7a0eb3e2d9c1406ce40f11f14ab03d4fdd8e7`](https://github.com/Lucian-prog/FPGA/commit/92b7a0eb3e2d9c1406ce40f11f14ab03d4fdd8e7)，只新增 10-05 音频报告，不计为新源码。
- 本轮提交一：[`40fb6b5f644a5805e8d2993d329fdb692f671095`](https://github.com/Lucian-prog/FPGA/commit/40fb6b5f644a5805e8d2993d329fdb692f671095)，新增 2 个流水乘法文件，99 行，提交时间 2026-10-06 13:24:43 UTC。
- 本轮提交二及**已审源检查点**：[`b4f9ff187e195b0b1121652e1f6101527215364d`](https://github.com/Lucian-prog/FPGA/commit/b4f9ff187e195b0b1121652e1f6101527215364d)，新增另外 6 个 RTL 文件，172 行，并修改根说明、新增 Bagu 说明；提交时间 2026-10-07 07:27:55 UTC。
- 父链：`b611af4（已审源）→92b7a0e（仅报告）→40fb6b5→b4f9ff1`。基线比较为 ahead=3、behind=0，共 11 个差异文件，其中 1 个是已存在的上一份报告；真正本轮输入为其余 10 个文件。
- 已核对 [10-05 报告的检查点与范围](https://github.com/Lucian-prog/FPGA/blob/b4f9ff187e195b0b1121652e1f6101527215364d/docs/code-reviews/FPGA-incremental-RTL-review-2026-10-05.md) 及 [10-03 Bagu 全量报告的范围](https://github.com/Lucian-prog/FPGA/blob/b4f9ff187e195b0b1121652e1f6101527215364d/docs/code-reviews/Bagu-review-2026-10-03.md)。本轮只扩展新文件，不重做旧 Bagu/音频全量审查，也不声称旧问题已经修复。
- 已读取完整递归树，491 个条目、`truncated=false`；根 [AGENTS.md](https://github.com/Lucian-prog/FPGA/blob/b4f9ff187e195b0b1121652e1f6101527215364d/AGENTS.md)、[Bagu/AGENTS.md](https://github.com/Lucian-prog/FPGA/blob/b4f9ff187e195b0b1121652e1f6101527215364d/Bagu/AGENTS.md)、[README.md](https://github.com/Lucian-prog/FPGA/blob/b4f9ff187e195b0b1121652e1f6101527215364d/README.md) 已读。新增三个主题目录及报告目录没有更深层适用的 AGENTS.md。
- 本轮新增主题目录仅含下表 8 个 RTL 文件，没有随提交进入仓库的对应 TB、README、构建脚本或约束；当前树没有 `.github/` 工作流。此结论针对这个仓库快照，不否认作者可能有未提交的本地验证资产。
- 报告只新增到 `docs/code-reviews/`，不修改源文件或已有报告；后续监测应继续跳过报告专属提交，使用上述源 SHA 作为检查点。

### 逐文件覆盖

下文短路径均相对于 `Bagu/`，全部源码链接固定到已审源 SHA。

| 文件 | 新增行数 | 已审内容 |
|---|---:|---|
| [mult_pipeline/pipeline/mult_pipeline.v](https://github.com/Lucian-prog/FPGA/blob/b4f9ff187e195b0b1121652e1f6101527215364d/Bagu/mult_pipeline/pipeline/mult_pipeline.v) | 60 | 全文；N 级例化、零扩展、级间数据/valid、输出索引和 N=1 |
| [mult_pipeline/pipeline/mult_unit.v](https://github.com/Lucian-prog/FPGA/blob/b4f9ff187e195b0b1121652e1f6101527215364d/Bagu/mult_pipeline/pipeline/mult_unit.v) | 39 | 全文；移位加法、非阻塞赋值、复位、空泡及位宽 |
| [mult_pipeline/No_pipeline/mult.v](https://github.com/Lucian-prog/FPGA/blob/b4f9ff187e195b0b1121652e1f6101527215364d/Bagu/mult_pipeline/No_pipeline/mult.v) | 60 | 全文；计数、首拍预计算、完成发布、取消与重启 |
| [arbitration/arbitration_fixed/arbit_fixed.v](https://github.com/Lucian-prog/FPGA/blob/b4f9ff187e195b0b1121652e1f6101527215364d/Bagu/arbitration/arbitration_fixed/arbit_fixed.v) | 27 | 全文；前缀请求累积、组合全赋值、优先级及复位屏蔽 |
| [arbitration/arbitration_fixed/arbit_fixed_adv.v](https://github.com/Lucian-prog/FPGA/blob/b4f9ff187e195b0b1121652e1f6101527215364d/Bagu/arbitration/arbitration_fixed/arbit_fixed_adv.v) | 12 | 全文；减一最低位隔离、表达式宽度、未使用时钟/复位 |
| [arbitration/arbitration_round/arbit_round.v](https://github.com/Lucian-prog/FPGA/blob/b4f9ff187e195b0b1121652e1f6101527215364d/Bagu/arbitration/arbitration_round/arbit_round.v) | 40 | 全文；one-hot 起点、旋转方向、空闲保持、单通道与推进条件 |
| [arbitration/arbitration_round/arbit_unit.v](https://github.com/Lucian-prog/FPGA/blob/b4f9ff187e195b0b1121652e1f6101527215364d/Bagu/arbitration/arbitration_round/arbit_unit.v) | 16 | 全文；双请求减起点、折叠回绕、base 前提 |
| [popcount/popcount.v](https://github.com/Lucian-prog/FPGA/blob/b4f9ff187e195b0b1121652e1f6101527215364d/Bagu/popcount/popcount.v) | 17 | 全文；累加完整赋值、结果范围、参数及语言边界 |
| [AGENTS.md](https://github.com/Lucian-prog/FPGA/blob/b4f9ff187e195b0b1121652e1f6101527215364d/AGENTS.md)（仓库根） | +17/-4 | 全文及差异；中文讲解、Verilog 默认版本与静态验证标注 |
| [Bagu/AGENTS.md](https://github.com/Lucian-prog/FPGA/blob/b4f9ff187e195b0b1121652e1f6101527215364d/Bagu/AGENTS.md) | +4 | 全文；本目录直接 RTL 审查约定 |

新增 RTL 覆盖 **8/8**；本轮非报告差异文件覆盖 **10/10**。全部新 RTL 都已阅读全文，未用片段替代完整模块。检索新增顶层名称未发现外部实例结果，但代码搜索可能有索引时效限制，因此不把它当作全仓无引用的证明。

### 分级

- **P1 高**：确定的主要功能失败或重大数据/事务损坏。
- **P2 中**：有明确触发场景的集成契约风险；条件不成立时不视为当前失败。
- **P3 低/契约提示**：参数防护、工程清晰度、实现前提或教学取舍。
- 本轮**确定功能缺陷 0 项，P1 0 项；列出 P2 条件风险 2 项**。未运行验证不能证明“没有其他问题”。

## 二、功能与复位的条件风险

### R01 · P2 · 仲裁器复位语义不一致，复位期间可能仍有授权

**类别：确定的输出差异；是否构成功能缺陷取决于集成契约。**

- 位置：[arbit_fixed.v:L12–L26](https://github.com/Lucian-prog/FPGA/blob/b4f9ff187e195b0b1121652e1f6101527215364d/Bagu/arbitration/arbitration_fixed/arbit_fixed.v#L12-L26)；[arbit_fixed_adv.v:L4–L10](https://github.com/Lucian-prog/FPGA/blob/b4f9ff187e195b0b1121652e1f6101527215364d/Bagu/arbitration/arbitration_fixed/arbit_fixed_adv.v#L4-L10)；[arbit_round.v:L22–L38](https://github.com/Lucian-prog/FPGA/blob/b4f9ff187e195b0b1121652e1f6101527215364d/Bagu/arbitration/arbitration_round/arbit_round.v#L22-L38)；[arbit_unit.v:L8–L13](https://github.com/Lucian-prog/FPGA/blob/b4f9ff187e195b0b1121652e1f6101527215364d/Bagu/arbitration/arbitration_round/arbit_unit.v#L8-L13)。
- 触发：`rst_n=0`，同时 `req` 非零；例如各实例取相同通道数且 `req=...0001`。
- 静态结果：普通 fixed 组合分支强制 `grant=0`；adv 不使用 `rst_n`，仍给 `grant=...0001`；round 在复位状态更新稳定后 `base=...0001`，其组合选择器同样给出有效授权。
- 后果：若调用者以为三者复位都能撤销请求，或用 grant 直接触发未同步复位的共享资源，替换实现/复位阶段可能产生意外操作。若 grant 在复位期间被下游明确忽略，则没有由此证明正常运行错误。
- 建议：在模块契约中统一选择“复位屏蔽 grant”或“组合授权、系统负责屏蔽”，并让实现和端口含义一致。若要互换两种 fixed，需特别处理这一差异；不要因为 `clk/rst_n` 出现在端口中就认为输出一定被寄存或复位。
- 补充：两个 fixed 的 `clk` 均未使用，都是组合电路；普通 fixed 的复位也是组合屏蔽。round 的复位作用于指针寄存器，不能描述成对 grant 的寄存清零。

### R02 · P2 · Round-robin 按“给出授权”推进，不按“完成服务”推进

**类别：带背压、多拍事务或要求按完成计数公平性时的条件风险；每拍授权即消费的教学用法成立。**

- 位置：[arbit_round.v:L13–L30](https://github.com/Lucian-prog/FPGA/blob/b4f9ff187e195b0b1121652e1f6101527215364d/Bagu/arbitration/arbitration_round/arbit_round.v#L13-L30) 及 [接口 L4–L7](https://github.com/Lucian-prog/FPGA/blob/b4f9ff187e195b0b1121652e1f6101527215364d/Bagu/arbitration/arbitration_round/arbit_round.v#L4-L7)。
- 触发：某拍非零 grant 没有被资源接受，或一个事务需要跨拍保持同一所有者。接口没有 `ready/accept/done/lock`，只要 `|grant` 就旋转起点。
- 静态反例：`CH=2,req=2'b11` 始终成立，复位后从通道 0 开始。若下游只在 grant 为通道 1 的拍可接受，而通道 0 的拍一直阻塞，指针仍交替推进；每次实际服务都可能属于通道 1，通道 0 持续请求却从未完成。这里公平的是候选授权次数，不是已完成服务次数。
- 后果：直接复用到 ready/valid 或总线占用仲裁时，等待中的选择可能变化，或者服务公平性不成立。多拍事务若没有额外 owner 锁存，也不能依赖当前 grant 保持所有者。
- 建议：若目标包含背压，增加明确的服务接受/完成条件，令指针只在真正服务后推进；若协议要求阻塞期间选择稳定，再锁存 grant/owner，完成后释放。若保持现教学接口，则注明请求在采样沿同步稳定、每个 grant 当拍可消费、无多拍锁定。
- 限定：对固定优先级仲裁，持续高优先级请求压住低优先级是算法本意，不应另报成“缺少 round-robin 公平性”的错误。

## 三、乘法流水：数据、valid、位宽与逐拍结论

### 1. N 级流水的目标及不变量

目标为两个无符号数 `A=mult1`、`B=mult2` 的全精度乘积：

`A×B = Σ（B[k] ? A×2^k : 0），k=0…N-1`。

[顶层 L19–L51](https://github.com/Lucian-prog/FPGA/blob/b4f9ff187e195b0b1121652e1f6101527215364d/Bagu/mult_pipeline/pipeline/mult_pipeline.v#L19-L51) 将首级累加输入清零，A 先补 N 个零扩展到 M+N 位；每级 [mult_unit.v:L25–L29](https://github.com/Lucian-prog/FPGA/blob/b4f9ff187e195b0b1121652e1f6101527215364d/Bagu/mult_pipeline/pipeline/mult_unit.v#L25-L29) 同时登记左移 A、右移 B 和当前最低位对应的累加结果。

处理完第 k 位后，属于同一事务的寄存状态为：

- 累加值 `A × (B mod 2^(k+1))`。
- 被乘数移位值 `A × 2^(k+1)`，存于 M+N 位。
- 乘数移位值 `B >> (k+1)`。
- valid 表示上述三个寄存结果都属于同一份有效输入。

最终 k=N-1，累加值就是 A×B。`(2^M-1)×(2^N-1) < 2^(M+N)`，所以顶层合法无符号输入的部分和及完整结果可以容纳于 M+N 位；没有少留一个乘积位。加法中间结果与目的宽度一致，在此数学范围内不会丢失有效进位。不能把此证明扩大到任意独立使用的 mult_unit 输入：外部若任意给满范围 i_mult_acc 与 mult1，相加当然仍可能按定宽截断。

### 2. 精确定义延迟，避免“一拍”口径混淆

以输入在采样沿 **C0** 被首级接受为起点，表中均表示相应时钟沿非阻塞赋值更新完成之后的状态；默认 N=4：

| 时刻 | 该事务所在级 | 已累计的乘数位 | 该事务的输出 valid |
|---|---|---|---|
| C0 后 | 第 0 级 | bit 0 | 尚未到末级 |
| C1 后 | 第 1 级 | bit 0～1 | 尚未到末级 |
| C2 后 | 第 2 级 | bit 0～2 | 尚未到末级 |
| C3 后 | 第 3 级 | bit 0～3 | 为 1，乘积同步就绪 |
| C4 沿 | 下游可采样 C3 后的输出 | 完整乘积 | 下游使用沿前 valid |

因此是 **N 个寄存级**：从 C0 接受到 C(N-1) 后输出可见，两者相隔 N-1 个完整周期；若从输入驱动的前一周期或到下游捕获沿计数，则常称 N 周期流水延迟。N=1 时首级即末级，在 C0 后就发布结果，下游在 C1 沿消费。写延迟断言时必须先统一采样口径，不把这些说法误判为 off-by-one。

### 3. 连续输入、空泡与复位

- [mult_pipeline.v:L43–L51](https://github.com/Lucian-prog/FPGA/blob/b4f9ff187e195b0b1121652e1f6101527215364d/Bagu/mult_pipeline/pipeline/mult_pipeline.v#L43-L51) 每一级使能来自 `valid[i-1]`，数据、移位量、累加值也全部来自 i-1。非阻塞赋值使各级读取同一时钟沿前的旧值，因此新事务不会覆盖同拍应送往下一级的旧事务。
- 连续 `mult_en=1` 时可每拍接受一份新输入，填满后可每拍输出一份。没有共享的跨事务累加寄存器。
- [mult_unit.v:L31–L35](https://github.com/Lucian-prog/FPGA/blob/b4f9ff187e195b0b1121652e1f6101527215364d/Bagu/mult_pipeline/pipeline/mult_unit.v#L31-L35) 在无效拍把数据和 valid 一起清零。这个清零表示空泡，不表示暂停整个流水；前一个有效数据仍已被下一级在该沿读取，不会被同拍清零追上。输出只在 mult_valid=1 时有事务意义。
- 例：N=4 时，C0 输入 A、C1 空泡、C2 输入 B，则对应末级分别在 C3、C4、C5 后成为 A/无效/B。这里只是控制关系手工推导，未生成或运行波形。
- [mult_unit.v:L18–L23](https://github.com/Lucian-prog/FPGA/blob/b4f9ff187e195b0b1121652e1f6101527215364d/Bagu/mult_pipeline/pipeline/mult_unit.v#L18-L23) 异步复位清除全部级的数据和 valid，在途事务被中止；不要求复位前输入在恢复后补发。复位释放与采样沿的物理关系仍须由系统保证。
- 接口没有 out_ready 或全流水 stall。消费者必须接住每个 mult_valid 周期，或在外部缓冲；当前源码没有宣称支持背压。

### 4. 迭代乘法器的控制闭合

证据：[mult.v:L18–L32](https://github.com/Lucian-prog/FPGA/blob/b4f9ff187e195b0b1121652e1f6101527215364d/Bagu/mult_pipeline/No_pipeline/mult.v#L18-L32)、[L34–L58](https://github.com/Lucian-prog/FPGA/blob/b4f9ff187e195b0b1121652e1f6101527215364d/Bagu/mult_pipeline/No_pipeline/mult.v#L34-L58)。

| 时刻（从 cnt=0 且 mult_en=1 的 C0 开始） | 行为 |
|---|---|
| C0 后 | 捕获 A/B，同时完成 bit 0 的部分积；cnt=1 |
| C1…C(N-1) 后（N>1） | 每拍继续处理一位并累加 |
| CN 后 | 沿前 cnt=N，将完整 mult_acc 复制到 mult_out，valid=1，cnt 回 0 |
| C(N+1) 后 | 若 mult_en 仍为 1，自动接受下一份输入并处理其 bit 0；valid 回 0 |

- 默认 N=4：C0～C3 共处理 4 位，C4 后发布；最小接受间隔为 **N+1=5 拍**。N=1：C0 已完成唯一部分积，C1 发布，没有漏掉最高位。
- `mult_en` 必须在 C0～CN 的 N+1 个采样沿均为 1，包括发布那一沿。源码第 18 行已经明确这一契约。单拍脉冲在下一拍拉低会取消，不能当作单拍 start。
- 运算期间使用捕获后的移位寄存器，外部 mult1/mult2 不必保持整段运算时间；仅在真正 cnt=0 的接受沿需要稳定。若 mult_en 连续保持，C(N+1) 的操作数自动成为下一笔，调用者须对齐该隐式接受点。
- 拉低 mult_en 使计数回 0、valid 清零；旧累加寄存器可以保留，因为下次 cnt=0 会完全覆盖它们。不会把被取消事务的部分积叠到下一笔。
- mult_out 只在完成/复位时更新，其余时间可保留上次结果；valid 默认每拍清零，只在完成分支置 1，不会持续误报完成。
- 32 位固定 cnt 对这些小参数功能充足，但不如按 N 推导的最小位宽清楚；具体资源能否被工具裁剪未验证。若以后做通用 IP，明确参数上限并用至少 1 位、能表示 0…N 的计数宽度，同时考虑增加 busy/ready 或独立 start/cancel，不能只改端口名而不改变协议。

## 四、仲裁、popcount 和参数的正向核对

### 仲裁算法

1. **普通 fixed：** [L18–L22](https://github.com/Lucian-prog/FPGA/blob/b4f9ff187e195b0b1121652e1f6101527215364d/Bagu/arbitration/arbitration_fixed/arbit_fixed.v#L18-L22) 使 req_prev[i] 为 req[0…i] 的 OR；grant[i] 仅在自身请求且更低编号无请求时置位。因此最低编号优先，req=0 时 grant=0；正 N 的全部位均在组合块中赋值，未发现 latch。
2. **减法 fixed：** [adv:L10](https://github.com/Lucian-prog/FPGA/blob/b4f9ff187e195b0b1121652e1f6101527215364d/Bagu/arbitration/arbitration_fixed/arbit_fixed_adv.v#L10) 的 `req & ~(req-1)` 隔离最低有效位。req=0 时，即使减法发生定宽回绕，与 req 相与仍为 0。
3. **不要误报 32 位边界：** `req-1` 中无尺寸十进制常量至少有 32 位，并不表示 CH>32 时 req 会被强行截成 32 位；表达式宽度会容纳更宽操作数。对小 CH，较宽运算的低 CH 位仍得到同一最低有效位结果。为可读性可将常量明确按通道宽度构造，但未据此发现 CH=33/64 的逻辑截断缺陷。
4. **环形选择：** [arbit_unit:L8–L13](https://github.com/Lucian-prog/FPGA/blob/b4f9ff187e195b0b1121652e1f6101527215364d/Bagu/arbitration/arbitration_round/arbit_unit.v#L8-L13) 将 req 复制两份；在 base 为单独一位 1 时，减法借位掩码隔离从该起点向高编号搜索的第一个请求，双份请求保证高端无候选时可回绕，最后 OR 折叠回 CH 位。
5. **指针方向/空闲：** [arbit_round:L13–L30](https://github.com/Lucian-prog/FPGA/blob/b4f9ff187e195b0b1121652e1f6101527215364d/Bagu/arbitration/arbitration_round/arbit_round.v#L13-L30) 从已授权位向下一更高编号旋转，最高位回到 bit 0；无请求时不更新 base。复位 one-hot、合法非零 grant one-hot、旋转保持 one-hot，故当前 wrapper 在正常复位后维持选择器所需前提。
6. **单通道：** CH=1 分支直接令 base_next=1，避免采用多通道分支中的 CH-2 切片；有效行为就是 grant=req。不能忽略 generate 条件而将未展开分支的切片当成当前 CH=1 必然错误。

### Popcount

证据：[popcount.v:L5–L14](https://github.com/Lucian-prog/FPGA/blob/b4f9ff187e195b0b1121652e1f6101527215364d/Bagu/popcount/popcount.v#L5-L14)。

- 目标为 N 位输入中 1 的个数，范围 0…N；宽度 `$clog2(N+1)` 对 N≥1 正好能表示最大计数，包括 N 为 2 的幂时的“全 1”情况。默认 N=16 输出 5 位，可表达 16；N=1 输出 1 位。
- 每次组合计算先置 count=0，再使用阻塞赋值累加所有位，已覆盖所有输入路径；不跨拍保留旧 count，不形成累加器寄存器或锁存器。中途部分计数不会超过 N，所以不是“每次 1 位相加只留 1 位”的错误。
- for 循环描述一拍内的组合加法，不是运行 N 个时钟周期。综合器可能重组加法网络，也可能保留较深链，不能从几行 RTL 直接承诺频率、面积或平衡树实现。
- `$clog2` 属于 Verilog-2005 支持的常量数学功能，并非只能在 SystemVerilog 中使用。若使用严格 Verilog-2001 前端，需相应常量函数或固定宽度替代；根约定的 Verilog-2005 路线不存在这一语言版本冲突。可参考 [Verilator 官方 Verilog-2005 支持说明](https://veripool.org/guide/latest/languages.html#verilog-2005-support)；本轮未调用该工具。

### P3 / 复用契约及边界清单

| 条件 | 当前结论与建议 |
|---|---|
| M、N、CH 正整数 | 是这些模块的实际有效域；没有声明支持零宽或负宽配置，应在说明/配置检查中明确 |
| 乘法 M=1 或 N=1 | 位宽与零扩展成立；流水 N=1 只有首级，迭代 N=1 仍有独立发布拍 |
| 仲裁通道数=1 | 普通 fixed、adv、round 及选择单元在合法 base 下成立 |
| popcount N=1、非 2 的幂、2 的幂 | 正参数计数宽度均足够；不要求 N 是 2 的幂 |
| 零参数 | `[N-1:0]` 等不会变成真正零位信号，可能成为意外反向范围；round 还涉及负重复次数，pipeline 末级索引也无有效含义。不要把工具是否接受语法等同于零通道功能成立 |
| arbit_unit 独立例化 | base 必须为 one-hot。base=0 时所有请求被屏蔽；CH=4、req=1111、base=0011 时 grant=0011，可多重授权。当前 round wrapper 会维持 one-hot，故不是当前 wrapper 默认缺陷 |
| 有符号乘法 | 端口均为 unsigned，右移为逻辑移位；补码负数输入会按无符号位模式解释。需要 signed 时必须重新定义扩展、部分积和输出解释，不能只加一个端口 signed 就宣称完成 |
| 参数化表达式极限 | 正常硬件规模内分析成立；未承诺无上限位宽，32 位迭代计数器及 N+1、2*CH 等参数运算均应有合理上限。未将超大不可实施配置列为默认功能缺陷 |
| 组合输出与时钟域 | 固定仲裁、选择单元和 popcount 没有输入同步或输出寄存，不能用端口含 clk 或组合公式短推导出无毛刺/可跨域；调用者应在同域稳定采样，不直接把 grant 当时钟 |
| 异步复位释放 | 流水、迭代及轮询指针采用低有效异步复位；物理使用需满足 recovery/removal 和域内一致释放。可由上层提供同步释放，不因每个叶模块没有同步器就断言当前数字逻辑错误 |
| 文件名与顶层名 | `arbit_round.v` 中声明的是 `arbit_round_robin`；清单/例化要用模块声明，不按文件名猜顶层 |

## 五、验证资产边界与后续建议

没有随这两个提交提供对应 TB 或执行记录；本轮也没有运行任何验证。`40fb6b5` 标题中的 “verified shift-add pipeline” 不等于当前仓库已经具备可复核的验证覆盖。下面只是以后另行授权验证时可采用的检查项，本次全部未执行：

1. 乘法：0、1、最大值、walking-one、非对称 M/N、M/N=1；用独立无符号数学期望核对满宽结果。
2. 流水：连续输入与任意空泡、每级在途复位、恢复后首个有效输出；分别记账输入/输出，按明确的 C0/C(N-1) 或下游消费口径检查延迟和事务顺序。
3. 迭代：保持使能到发布；每个计数阶段拉低取消、取消后马上重启、持续使能连续两笔、计算中改变外部输入；证明取消无输出、每个完整事务恰好一个完成脉冲。
4. 仲裁：req=0、每个单请求、全部请求、稀疏集合、最高位回绕、空闲保持和 CH=1/2/3/16/33/64；检查 grant 为 one-hot-or-zero 且 grant 是 req 的子集，起点变化规则与接口契约一致。
5. 若扩展带背压仲裁：加入阻塞期间稳定性、真实接受后才推进、持续请求的服务公平性、多拍 owner 锁定和复位中止检查；先改清楚规格，再判断现有算法是否满足。
6. Popcount：全 0、全 1、交替位、单 bit、不同正 N，区分值正确性与组合路径时序。
7. 以后若进行器件实现，再确认长组合加法/优先级路径、N 级寄存器规模、异步复位网络与目标频率；本报告不提供资源/Fmax/时序签核结论。

## 六、处理建议与交付边界

优先补清仲裁复位和真实服务事件契约，其次写明两种乘法器不同的输入协议及精确延迟口径，再补充正参数/one-hot/unsigned 前提。只有目标确实需要背压、事务锁定或有符号数时才扩展接口，不为面试练习无条件增加复杂状态机。

本轮没有确定的默认算术缺陷需要替代源码；保留已经合理的级间 valid、全精度零扩展、空泡处理、迭代完成脉冲与 CH=1 分支。已审源检查点为 `b4f9ff187e195b0b1121652e1f6101527215364d`；报告提交本身不能替换该源检查点。交付仅追加本 Markdown，不强推、不改写历史、不合并或部署，不表示全仓问题已清零或设计可直接上板。
