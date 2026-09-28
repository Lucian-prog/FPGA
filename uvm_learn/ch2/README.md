# UVM 实战 第 2 章 验证平台

《UVM实战》（张强）第 2 章的完整验证平台，基于 **Rocky VM + VCS W-2024.09（UVM 1.2）** 跑通。

## 平台结构

```
                    ┌──────────────── my_env ────────────────┐
                    │                                        │
 my_sequence        │  ┌─────── i_agt (ACTIVE) ───────┐      │      ┌──── o_agt (PASSIVE) ────┐
      │             │  │  sequencer → driver           │      │      │  monitor                │
      ▼             │  │      ▲        │              │      │      │    ▲                    │
 default_sequence   │  │      │        ▼              │      │      │    │                    │
 (config_db)        │  │      │    my_if(rxd/rx_dv)   │      │      │    │                    │
      │             │  │      │        │              │      │      │    │                    │
      └────────────►│  │ sqr ───┘    monitor            │      │      │    │                    │
                    │  │              │ ap              │      │      │    │ ap                 │
                    │  └──────────────┼─────────────────┘      │      └────┼────────────────────┘
                    │                 ▼                        │           │
                    │      agt_mdl_fifo (uvm_tlm_analysis_fifo)│           │
                    │                 │                        │           │
                    │                 ▼ get                     │           │
                    │            ┌─────────┐                    │           │
                    │            │  model  │ copy + print       │           │
                    │            └────┬────┘                    │           │
                    │                 │ ap (期望值)              │           │
                    │                 ▼                         ▼           │
                    │            ┌──────────── scoreboard ────────────┐    │
                    │            │  model_imp    vs    monitor_imp    │    │
                    │            │  (expect_queue 逐笔 compare)       │    │
                    │            └────────────────────────────────────┘    │
                    └────────────────────────────────────────────────────────┘

 DUT：rxd/rx_dv 打一拍直通 txd/tx_en（书上清单 2-1）
```

- **数据流**：sequence 随机出 10 个以太网帧 → driver `pack_bytes` 拆字节流逐拍驱动 → DUT 打一拍 → o_agt.monitor 采集实际输出；i_agt.monitor 采集输入 → model 复制为期望值 → scoreboard 的 `expect_queue` 逐笔比对。
- **双 analysis imp**：scoreboard 用 `uvm_analysis_imp_decl(_monitor)/(_model)` 声明两个 imp，分别收实际/期望数据。

## 文件清单

| 文件 | 对应书上内容 |
|------|-------------|
| `dut.sv` | 清单 2-1 |
| `my_if.sv` | 2.2.1 interface |
| `my_transaction.sv` | 2.3.1（field automation） |
| `my_sequencer.sv` | 2.4.1 |
| `my_sequence.sv` | 2.4.2 |
| `my_driver.sv` | 2.2.2 |
| `my_monitor.sv` | 2.3.3（queue 收集 + unpack_bytes） |
| `my_agent.sv` | 2.4.4（active/passive 双模式） |
| `my_model.sv` | 2.3.2（blocking_get_port + analysis_port） |
| `my_scoreboard.sv` | 2.3.4（expect_queue + compare） |
| `my_env.sv` | 2.3.5（组件创建 + TLM 连接） |
| `base_test.sv` | 2.5.1（含 my_case0） |
| `top_tb.sv` | 2.5（顶层，interface 实例化 + run_test） |
| `Makefile` | — |

## 运行（Rocky VM，`~/workspace/uvm_learn/ch2/`）

```bash
make comp && make run
```

或 `make all`。`make clean` 清理产物。

## 仿真结果（2026-09-01）

```
driver:    10 个 transaction 驱动
monitor:   输入 10 + 输出 10 = 20 次采集
model:     10 个期望 transaction
scoreboard: 10 笔比较全部通过
UVM_ERROR: 0    UVM_FATAL: 0
TEST PASSED!!!
```

## 与书上不同的三处修改（UVM 1.1d → 1.2）

书基于 UVM 1.1d，VCS 用的是 uvm-1.2，以下三处照抄书会跑不通/假通过：

1. **`top_tb.sv`**：config_db 的 `set` 与 `run_test` 放在**同一个 initial 块**。
   SV 不保证不同 initial 块的执行顺序；若 `run_test` 先执行，build_phase 在 t=0 的 `get` 会因资源未 set 而 fatal。
2. **`top_tb.sv`**：set 路径写 `uvm_test_top.env.i_agt*`（通配），不是书上的精确路径。
   **config_db 的路径是正则语义**：`i_agt` 匹配不了 `i_agt.drv`；用 `+UVM_CONFIG_DB_TRACE` 能看到 SET 成功 / GET failed 的对照。
3. **`my_sequence.sv`**：new 里 `set_automatic_phase_objection(1)`，去掉书上 body 里的
   `starting_phase.raise_objection`。**UVM 1.2 的 default_sequence 不再设置 starting_phase**，
   书上写法 starting_phase 为 null，objection 无人 raise，main_phase 瞬间结束（0 驱动 0 比较）。

另有一处增强（非修正）：**`base_test.sv`** 的 main_phase 里
`phase.phase_done.set_drain_time(this, 1us)`（书上 5.2.4 的内容）。
没有它会出现「10 驱动只比较 9」的**假通过**——sequence 撤销 objection 时，最后一笔数据还在
DUT → o_agt → scoreboard 的路上。

## 面试考点速记

- config_db 路径匹配是**正则/通配**语义，不是纯层次继承；`get` 失败先怀疑路径，`+UVM_CONFIG_DB_TRACE` 是第一诊断工具。
- UVM 1.1d 与 1.2 的差异：default_sequence 的 `starting_phase`、`set_automatic_phase_objection`。
- **objection drain time** 防假通过：比较路径有延迟时，phase 结束必须给数据留时间，否则报 PASS 不可信。
- SV 中不同 `initial` 块顺序未定义，任何「先 set 后 run_test」的隐式依赖都要放进同一块。
