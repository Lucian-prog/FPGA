# 2.2 复现记录：从裸 class 到最小 UVM 平台

> 配套代码：[sec2_2/](sec2_2/)，已在 Rocky VM + VCS W-2024.09（UVM 1.2）实跑通过，日志见文末。
> 书：2.2 节（P8–20）。读法建议：先通读本文，再照着 sec2_2 的代码回到书上逐段对照。
> 书是 UVM 1.1d，实跑环境是 UVM 1.2，本文所有代码按 1.2 规范书写，与书的差异集中在文末清单。

## 2.2 在造什么

第 2 章的最终平台有七个组件、两条数据流，直接看会晕。书很聪明，先只造一个**只有 driver 的平台**：driver 随机组一帧以太网数据，逐字节打给 DUT，仅此而已——没有检查，没有 transaction，甚至一开始连 interface 都接不上。

就是这么个残缺的平台，被迫引入了 UVM 的四个基础机制，一小节一个：

| 版本 | 引入的机制 | 被逼出来的问题 |
|------|-----------|----------------|
| v1 | driver 写成 class | UVM 世界里组件长什么样 |
| v2 | factory + run_test | 实例由谁创建？phase 由谁调度？ |
| v3 | objection | 仿真到底什么时候结束？ |
| v4 | virtual interface + config_db | class 的手怎么伸进 module 的信号里？ |

每一版都是「上一版 + 一个新机制」。下面按这个顺序走一遍。

## v1：driver 只是个普通的 class

先解决「driver 用什么写」。Verilog 时代的激励都是 module 里的 initial 块，写死、难复用。UVM 用 class 写组件，先搭出最简的三件套：DUT、interface、driver。

interface 把驱动相关的信号捆在一起（[my_if.sv](sec2_2/my_if.sv)）：

```systemverilog
interface my_if(input logic clk, input logic rst_n);
    logic [7:0] data;    // 数据字节
    logic       valid;   // data 有效指示
endinterface
```

driver 第一版相当朴素——一个继承了 `uvm_driver` 的 class，`main_phase` 里只打一条消息（[v1 版 main_phase]）：

```systemverilog
class my_driver extends uvm_driver;
    function new(string name = "my_driver", uvm_component parent = null);
        super.new(name, parent);
        `uvm_info(get_type_name(), "new is called", UVM_LOW)
    endfunction

    virtual task main_phase(uvm_phase phase);
        `uvm_info(get_type_name(), "main_phase is called", UVM_LOW)
    endtask
endclass
```

注意两个 new 参数：`name` 是实例名，`parent` 是树上的父结点。现在 parent 还只能是 null，因为树上还没有别人——这个参数的真正含义到 v2 才揭晓。

怎么让它跑起来？最直觉的写法是在 top_tb 里手动创建、手动调用：

```systemverilog
// v1 版 top_tb 的尝试（书上的写法，仅作反面教材）
initial begin
    my_driver drv;
    drv = new("drv", null);
    drv.main_phase(null);    // phase 参数传 null
end
```

跑起来确实能看到两条 info，但书上随即指出这条路走不通，理由有两个：

1. **创建权**。`drv = new(...)` 是完全绕开 UVM 的野路子，UVM 对这个实例一无所知——没法给它挂树、没法管它的生命周期、更没法做后续章节的 factory 重载。
2. **调度权**。UVM 里 phase 由 UVM 统一调度，`main_phase(null)` 手动传 null 是在冒充调度者。此刻侥幸不崩，是因为 v1 的 main_phase 里还没调 `phase.raise_objection`——一旦调了，拿着没对象的句柄去举手，仿真当场崩掉。

所以 UVM 规定：**平台必须由 `run_test` 启动**。这就是 v2。

## v2：factory 与 run_test——把创建权交给 UVM

`run_test("my_driver")` 收到的是**类名**，它要凭字符串创建实例，靠的就是 factory。前提是这个类在 factory 注册过——类的内部加一行宏（[my_driver.sv](sec2_2/my_driver.sv) 现在的样子）：

```systemverilog
class my_driver extends uvm_driver;
    // factory 注册：宏展开后是一大段登记代码，
    // 让 factory 认识 my_driver，才能凭 "my_driver" 这个字符串造出实例
    `uvm_component_utils(my_driver)

    // UVM 约定：组件的 new 必须是 name + parent 两个参数，
    // factory 创建实例时按这个签名调用，不按这个签名写，注册宏编译不过
    function new(string name, uvm_component parent);
        super.new(name, parent);
        `uvm_info(get_type_name(), "new is called", UVM_LOW)
    endfunction

    virtual task main_phase(uvm_phase phase);
        `uvm_info(get_type_name(), "main_phase is called", UVM_LOW)
    endtask
endclass
```

top_tb 相应改造：

```systemverilog
`include "uvm_macros.svh"
import uvm_pkg::*;          // run_test 和所有 UVM 的类都在 uvm_pkg 里

initial begin
    run_test("my_driver");   // 平台入口：创建实例、调度全部 phase、收尾
end
```

这一改，两件事自动发生了。其一，`new is called` 和 `main_phase is called` 都打出来了——**new 是 factory 调的，main_phase 是 phase 调度器调的**，之前 v1 里手动干的两件事现在都归了 UVM。其二，看日志的实例名：

```
UVM_INFO my_driver.sv(24) @ 0: uvm_test_top [my_driver] new is called
```

类明明叫 my_driver，日志里却是 **uvm_test_top**——`run_test` 创建的树根实例一律被强制改名为 uvm_test_top，不管实际类名是什么。这不是冷知识：v4 里 config_db 的路径要以它开头。

顺带留个伏笔：书 2.2.2 只讲了注册，`type_id::create` 的写法要到 2.3 才大量出现。区别一句话——`new` 是自己直接造对象，`create` 是向 factory 下单、由 factory 造；factory 造的才有资格被 factory 换掉（第八章的重载机制）。**UVM 里所有组件一律注册 + create，先当规矩执行。**

## v3：objection——仿真该什么时候结束

v2 的 main_phase 里只有一条打印，零耗时，phase 一瞬间就结束了，仿真收工退出。现在这无所谓，但真平台的 main_phase 要跑几百万拍——**UVM 凭什么知道你的活干完了没有？**

答案就是 objection 机制：想干活的人先举手（raise_objection），UVM 看到还有人举着就不结束 phase；所有人放下（drop_objection）的瞬间，phase 结束。用法是严格配对的：

```systemverilog
virtual task main_phase(uvm_phase phase);
    phase.raise_objection(this);    // 开工前举手
    `uvm_info(get_type_name(), "main_phase is called", UVM_LOW)
    phase.drop_objection(this);     // 收工放下
endtask
```

`this` 表示「是我举的手」，计数器加一；drop 时减一，归零即结束。两条铁律：raise 和 drop 必须配对（只 raise 不 drop，phase 永远不结束，仿真挂死）；**计数归零的瞬间 phase 立即结束，不会等任何人**——后者埋着一个大坑：如果撤销 objection 时最后一笔数据还在 DUT 里没流出来，比较就少一笔，「10 驱动只比较 9」的假通过。第 2 章最终平台用 `set_drain_time` 解决了它（[study_notes.md](study_notes.md) 坑④），现在只需记住：谁干活谁举手。

## v4：virtual interface——class 的手伸进 module 世界

前三版 driver 都没碰真实信号，现在要动真格了：把 data/valid 打出去。可是 my_if 的实例 `input_if` 在 top_tb（module 世界），而 driver 是 class（软件世界）——**class 里没法直接引用一个接口实例**，编译器都不允许。

SV 给的桥就是 virtual interface：在 class 里声明一个 `virtual my_if vif`，它本身不是接口，是**存了某个接口实例地址的句柄**——好比拿到外设的基地址才能读写它的寄存器，拿着这个地址才能驱动接口里的信号。剩下的问题是：top_tb 里那个具体的 `input_if`，怎么把它的地址递到 driver 手里？UVM 的答案是 config_db——一个按「收件人路径 + 字段名」存取的全局仓库。

driver 侧，在 build_phase 里取（**v4 新增的完整 build_phase**）：

```systemverilog
virtual my_if vif;    // 成员声明

virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // 从 config_db 取 vif。参数：this（谁取）、""（发给我自己）、
    // "vif"（字段名，和 set 时的对应）、vif（取到的值写进这个成员）
    if (!uvm_config_db#(virtual my_if)::get(this, "", "vif", vif))
        `uvm_fatal(get_type_name(), "virtual interface 'vif' must be set")
endfunction
```

取失败直接 `uvm_fatal`：没有 interface 的 driver 什么都驱动不了，带病运行没有意义。

top_tb 侧，在 run_test 之前存：

```systemverilog
initial begin
    // 收件人写 uvm_test_top：树根是 run_test 创建的 my_driver 实例，
    // 创建后强制改名（v2 讲过），config_db 认的是这个名字。
    // 视野参数传 null，路径就从 uvm_test_top 写起，叫绝对路径。
    uvm_config_db#(virtual my_if)::set(null, "uvm_test_top", "vif", input_if);
    run_test("my_driver");
end
```

注意 set 和 run_test 被放进了**同一个 initial 块**——这不是随手。SV 不保证不同 initial 块的执行顺序，若 run_test 先启动，build_phase 里的 get 会因资源还没 set 而 fatal。这是 ch2 完整平台真实踩过的坑，从一开始就按安全写法来。

最后把驱动逻辑补进 main_phase，组一帧最小以太网逐字节打出去（完整实现见 [sec2_2/my_driver.sv](sec2_2/my_driver.sv)，注释到行）：

```systemverilog
virtual task main_phase(uvm_phase phase);
    phase.raise_objection(this);
    `uvm_info(get_type_name(), "main_phase is called", UVM_LOW)

    vif.valid <= 1'b0;
    while (!vif.rst_n)              // 等复位释放再开工
        @(posedge vif.clk);
    drive_one_pkt();                // 组帧 + 逐字节驱动

    repeat (10) @(posedge vif.clk); // 帧发完空跑几拍，波形好看些
    phase.drop_objection(this);
endtask
```

## 组装与实跑

最终文件就五个（vcs 只编 top_tb 和 dut，其余由 `include` 带入）：

| 文件 | 内容 | 对应书上 |
|------|------|----------|
| `dut.sv` | 直通 DUT | 清单 2-1 |
| `my_if.sv` | interface 定义 | 2.2.1 |
| `my_driver.sv` | 最终版 driver（v1 骨架 + v2 注册 + v3 objection + v4 驱动） | 2.2.1–2.2.4 |
| `top_tb.sv` | 时钟复位 + interface 实例 + config_db + run_test | 2.2.2/2.2.4 |
| `Makefile` | `make` 一键编译运行 | — |

在 VM 上 `~/workspace/uvm_learn/ch2/sec2_2/` 下 `make`，真实输出：

```
UVM_INFO my_driver.sv(24) @ 0: uvm_test_top [my_driver] new is called
UVM_INFO @ 0: reporter [RNTST] Running test my_driver...
UVM_INFO my_driver.sv(42) @ 0: uvm_test_top [my_driver] main_phase is called
UVM_INFO uvm_report_server.svh(904) @ 890: reporter [UVM/REPORT/SERVER]
--- UVM Report Summary ---
** Report counts by severity
UVM_INFO :    4
UVM_WARNING :    0
UVM_ERROR :    0
UVM_FATAL :    0
$finish called from file ".../uvm_root.svh", line 527.
$finish at simulation time                  890
```

逐条读这个日志，每一行都对应前面一版讲过的机制：

- `@ 0 ... new is called`——factory 在 t=0 创建实例（v2）；
- 实例显示为 `uvm_test_top`——树根强制改名（v2），config_db 的 set 路径因此写它（v4）；
- `[RNTST] Running test my_driver...`——run_test 的例行通告；
- `main_phase is called` 后到 890ns 才退出——中间驱动了一帧 28 字节 + 10 空拍 + 复位期，全靠 objection 撑着（v3）；没有它 phase 在 t=0 打完印就散场了；
- `$finish` 来自 `uvm_root.svh`——所有 phase 自然跑完后 UVM 主动退出，不是我们调的。

激励线通了一半：driver → DUT 的路是有了，但「产生激励」还焊死在 driver 内部，输出没人看、更没人比——验证根本还没发生。把这两个缺口补上的，就是 2.3。

## 与书 1.1d 写法的差异（本节范围）

| # | 位置 | 本复现的写法 | 说明 |
|---|------|--------------|------|
| 1 | top_tb | set 与 run_test 放同一 initial | SV 不保证 initial 间顺序，这是安全的工程写法（ch2 坑①的经验提前用上） |
| 2 | my_driver | main_phase 开头等复位释放 | 书上最终版 driver 也有此逻辑，复现保留 |
| 3 | config_db | 全部用 `uvm_config_db#(T)` | 1.1d 的 `set_config_object` 等旧 API 在 1.2 已废弃，书上 3.5.9 讲到的 set_config/get_config 可跳过 |
| 4 | 帧数据 | MAC/载荷为示例值，CRC 填占位常数 | 书上未展开 CRC32 算法；2.2 阶段没有 checker，占位不影响 |

除这些外，2.2 的机制（factory 注册、run_test、objection、config_db）在 1.1d 与 1.2 间写法完全兼容——真正的分水岭在 sequence 的 starting_phase（2.4），到时再说。

## 读完自查

1. v1 里 `drv = new(...)` 加 `drv.main_phase(null)` 错在哪？（两个层面：创建权、调度权）
2. `run_test("my_driver")` 跑起来后，日志里实例名为什么是 `uvm_test_top`？它决定了 v4 里 config_db 的哪个参数？
3. 动手题：把 main_phase 里的 raise/drop 两行删掉重新跑，仿真输出和结束时间有什么变化？为什么？
