# UVM 学习总计划（项目驱动 · 目标：可投递数字 IC 验证实习）

> 2026-09-01 制定，取代原「6 周按书通读」计划。《UVM实战》从主线教材降级为字典：按需查，不通读。
> 本文件是活文档：每天收工更新进度 checkbox，journal 照常写日报。

## 目标定义（UVM Level 2）

拿到一个中小型 RTL DUT，能基本独立搭建 SystemVerilog/UVM self-checking 验证环境，
用 VCS + Verdi 完成仿真、自动检查和 debug，并在面试中完整解释整个流程。

## 现状盘点（第 2 章平台已完成，这不是从零开始）

> 注意：下表现值按「ch2 平台搭过**且知识已内化**」估计。若 ch2 笔记还没读，先完成 Phase 0（第 2 章内化），盘点才成立。

| Level 2 能力项 | 现状 | 补齐位置 |
|---|---|---|
| 组件架构（transaction/sequence/sqr/drv/mon/agent/scb/env/test） | 60% — 照书搭过全平台 | Phase 2 脱模板重写 |
| 完整 transaction 数据流 | 90% — 亲手打通 + 踩过 4 个坑 | Phase 2 固化 |
| phase / objection / config_db / analysis port | 80% — 会用 + 懂 1.1d/1.2 差异 | 按需查 3.5/4.3/5.x |
| constrained-random | 30% — 只见过 `uvm_do` | Phase 3 重点 |
| reference model + scoreboard | 70% — 做过直通模型 | Phase 2 升级为队列模型 |
| FIFO corner case（full/empty/连续/同时读写） | 0% | Phase 3 |
| functional coverage（covergroup/coverpoint/bins/cross） | 0% — **书上没有这章** | Phase 3 导师直接教 |
| VCS + Verdi 仿真 debug | 50% — VCS 流程熟，Verdi UVM 流程未练 | Phase 3 专题 |
| 脱离模板为另一个 DUT 重建环境 | 0% | Phase 4 |

## 训练 DUT（都用仓库里自己写的 RTL）

1. **`16. async_fifo/`**（Phase 2–3 主 DUT）：双时钟域，写域 `wrclk/wren/wrdata[15:0]/full/almost_full/wrusedw`，读域 `rdclk/rden/rddata/empty/rdusedw`，参数 `DATA_WIDTH/ADDR_WIDTH/FULL_AHEAD/SHOWAHEAD_EN`。
   隐藏问题（Day 1 要自己想）：默认 `ADDR_WIDTH=16` 意味着深度 2^16——验证"写满"该怎么办？
2. **`17. apb/`**（Phase 4 二次训练）：APB3 从机，4 个 32 位寄存器，PSTRB 字节选通、PSLVERR 越界错误。参考模型即 4×32 寄存器组。

## 总路线：14 个有效日（±2 弹性），前置 Phase 0 另计

| 天 | 阶段 | 任务 | Milestone |
|---|---|---|---|
| P0 | ⓪ | 第 2 章内化：按 `ch2/ch2_notes.md` §0 的 15 步顺序读（书 P7–55 + 对照代码；语法先过第一部分） | M0: 导师面试 5 题过关 |
| D1 | ① | FIFO RTL 精读 + 验证计划 | M1: verif_plan.md（feature/corner/testcase 表） |
| D2 | ② | interface + transaction + sqr + driver + top_tb | M2: directed 写 N 读 N 冒烟通过 |
| D3 | ② | monitor + agent + env | M3: 采集打印正确，ACTIVE/PASSIVE 可切换 |
| D4–5 | ② | scoreboard + 行为参考模型 | M4: 自检闭环 PASS + 人为 mismatch 定位演练 |
| D6 | ③ | constrained-random 序列族 + 多 seed 回归脚本 | M5a: 随机回归 10 seed 全绿 |
| D7 | ③ | corner 定向用例集 | M5b: 验证计划 testcase 表逐条销号 |
| D8 | ③ | functional coverage | M5c: covergroup 跑通 + 补 hole 到功能点全覆盖 |
| D9 | ③ | Verdi debug 专题（fsdb dump + 注 bug 演练） | M5d: 2–3 个注入 bug 独立定位 |
| D10 | ③ | FIFO 收尾：回归全绿 + README + 面试自测 | M6: FIFO 项目可写简历 |
| D11 | ④ | APB slave：独立验证计划 + 骨架（不看 FIFO 代码） | M7: 骨架编译通过 |
| D12–13 | ④ | APB env 完整：协议 driver + protocol check + scb + coverage | M8: 定向+随机全绿 |
| D14 | ④ | 收尾：总结 + 简历项目段定稿 + 模拟面试 | M9: 能脱稿讲全流程 |

## 各阶段详情

### Phase 1（D1）：验证计划先行

- 精读 `async_fifo.v / async_fifo_ctrl.v / dpram.v`，画出结构图；
- 写 `fifo_verif_plan.md`：feature 列表 → corner case 清单 → testcase 表（含每条的通过判据）；
- 必须覆盖的问题：深度 2^16 怎么处理、SHOWAHEAD_EN 两种模式怎么验、full 时继续写的行为（按 RTL 规格定）、复位中途读写。
- 面试点：**验证计划怎么写**（feature 提取、可测性、通过判据）。

### Phase 2（D2–5）：FIFO 环境骨架，自检闭环

单 interface 打包双时钟域信号 + 单 agent（不拆多 agent，virtual sequence 因此不需要）。
每天推进一个组件，每个组件过四问：**解决什么问题 / 在数据流什么位置 / 与上下游怎么通信 / 没有它会怎样**。

- D2：`fifo_if`（含 wr/rd 两个 clocking 块）、`fifo_item`、`sequencer`、`driver`、`top_tb`。先通激励线，不接检查。
- D3：`monitor`（写侧采集 + 读侧采集）、`agent`（active/passive）、`env` 骨架。
- D4–5：`scoreboard` + 行为模型（SV 队列实现预期 FIFO 语义，含 full/empty 判断）；故意在 DUT 或 model 里制造一笔 mismatch，练「从 scb 报错反推定位」。
- 按需书页：4.3.2 多 IMP P121、4.3.3 FIFO 通信 P124、4.3.5 用 FIFO 还是 IMP P128。

### Phase 3（D6–10）：从「能跑」到「验证完备」

- D6 constrained-random：读写比例、burst 长度、idle 插入全部约束化；多 seed 回归脚本（简历素材）。按需书页：6.3 P175–181（start_item/finish_item P178）、6.4.2 P183。
- D7 corner 定向：写满→读空、full 后继续写、同时读写、back-to-back、复位中途——逐条对应验证计划表。
- D8 functional coverage（**书无此章，直接教学**）：covergroup 放哪（uvm_subscriber）、coverpoint（操作类型/水位/burst 长度）、bins、cross（读写并发 × 水位）、采样时机、coverage-driven 补用例。高频面试题：**code coverage vs functional coverage**。
- D9 Verdi 专题：`$fsdbDumpfile/$fsdbDumpvars` 配置、Verdi 追 transaction 数据流；导师注入 2–3 个 RTL bug，独立走「读 log → 判断错误类别 → Verdi 波形 → 追数据流」流程。
- D10 收尾：回归全绿 + coverage 达标 + 项目 README + 面试 10 题自测。

### Phase 4（D11–14）：APB Slave 二次独立训练

- 检验标准：**不看 FIFO 代码**重新搭，允许查书和 UVM 类参考，不允许复制模板改名字；
- 新知识增量：协议型 driver（IDLE→SETUP→ACCESS 相位）、protocol check（PSEL/PENABLE 时序）、内存型参考模型、错误场景（PSLVERR 越界、PSTRB 选通）；
- D14 定稿简历项目段 + 模拟面试。

## 按需阅读地图（书页，PDF = 书页 + 13）

| 主题 | 位置 | 何时查 |
|---|---|---|
| config_db 全解 | 3.5 P85–99（通配符 3.5.7 P94、调试 3.5.10 P98） | 已用会，卡住时查 |
| field automation 细节 | 3.3 P69–76 | coverage/pack 需要时 |
| TLM 端口互连 | 4.2 P104–119 | 连线报错时 |
| analysis 端口 / 多 IMP / FIFO | 4.3.1–4.3.5 P119–128 | D4 scoreboard 时 |
| phase 机制 | 5.1 P132–148（执行顺序 P134、超时 P147） | 已会，按需 |
| objection / drain_time | 5.2 P148–158（P152/P154/P156） | 已会，按需 |
| sequence 宏 / start_item | 6.3 P175–181 | D6 约束随机时 |
| sequence 进阶（rand 类型、派生） | 6.4 P181–190 | D6–7 按需 |
| **functional coverage** | **本书没有** | D8 导师教 |
| RAL 第7章 P216 / factory 第8章 P260 / callback 9.1 P285 / virtual seq 6.5 P190 | — | 搁置（见下） |

## 明确搁置（解冻条件）

- RAL（P216）：APB 项目需要寄存器自动化时才解冻，v1 不用；
- factory override（P260）、callback（P285）：注错用 error-injection sequence 替代；
- virtual sequence（P190）、multi-agent：单 agent 方案已避开；拆分确有必要时再学；
- layer sequence（P315）、UVM 源码、高级 SVA、formal、大型 VIP 架构：实习面试不依赖。

## 协作规则（导师模式）

1. 我给需求说明、文件清单、接口签名和空壳框架；**主体实现由主人写**，贴代码我 review；
2. bug 处理：先读 VCS log → 判断错误类别（compile / UVM connection / timing / DUT functional）→ Verdi 波形 → 沿 transaction 流追源头；不直接给答案，除非主人明说「直接告诉我」；
3. 每个 milestone 配 1–3 道面试题，答不上回炉对应知识点；
4. 开工口令「开始 Day N」，收工更新本文件进度 + 写 journal 日报；
5. 简历红线：只写真正做过、能被追问三层的技术词。

## 进度追踪

- [ ] P0 第 2 章内化（M0）
- [ ] D1 验证计划（M1）
- [ ] D2 激励线冒烟（M2）
- [ ] D3 监控线（M3）
- [ ] D4–5 自检闭环（M4）
- [ ] D6 随机回归（M5a）
- [ ] D7 corner 用例（M5b）
- [ ] D8 功能覆盖率（M5c）
- [ ] D9 Verdi debug（M5d）
- [ ] D10 FIFO 收尾（M6）
- [ ] D11 APB 计划 + 骨架（M7）
- [ ] D12–13 APB 完整（M8）
- [ ] D14 收尾 + 简历（M9）
