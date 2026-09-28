# 第 2 章学习笔记：一个简单的 UVM 验证平台

> 配套代码：本目录（已在 VCS + UVM 1.2 上跑通，平台说明见 README.md）
> 书：《UVM实战》第 2 章，**书 P7–55**。PDF 页码 = 书页码 + 13（书 P7 = PDF P20）。

---

## 0. 推荐阅读顺序

### 0.1 书第 2 章是渐进式搭建

书不是一次给出最终代码，而是**像搭积木一样反复改同一批文件**：
先写只有 driver 的最小平台（2.2）→ 加 transaction/env/monitor/agent/model/scb（2.3）→ 加 sequence（2.4）→ 加 test（2.5）。

所以同一个文件名 `my_driver.sv` 在书里出现了五六次（清单 2-1x、2-24、2-60、2-61、2-65、2-68…），**内容每次都不同**。第一次读很容易在这里迷失。

**对策**：
- 本目录的代码 = 书 2.3.7 + 2.4 + 2.5 全部组装完的**最终形态**，只看这一份就够；
- 书上的代码清单用于理解「这个组件是怎么一步步长出来的」，每节读完知道该版本引入了什么新东西即可；
- 哪个清单对应最终形态：driver=2-65、monitor=2-57、model=2-53、scoreboard=2-54（其中 scb 的 imp 写法我们改用了 4.3.2 的 `uvm_analysis_imp_decl`）、env=2-47+2-36+2-46 的合体、agent=2-62+2-64、test=2-74/2-76、top_tb=2-75。

### 0.2 第一轮阅读顺序（建立全貌，约 4–6 小时）

| 步骤 | 读什么 | 书页 | 配套动作 |
|------|--------|------|----------|
| ① | 2.1 验证平台的组成 | P7–8 | 只看图 2-1/2-2，能说出五个框各干嘛（对照本笔记 §2） |
| ② | 2.2.1 最简单的验证平台 | P8–13 | **概念为主，快速过**——看「没有 UVM 机制时平台多难受」，体会后面每个机制的动机 |
| ③ | 2.2.2 factory | P13–14 | 读笔记 §3.1，再看 2.2.2 |
| ④ | 2.2.3 objection | P14–16 | 读笔记 §3.2，再看 2.2.3 |
| ⑤ | 2.2.4 virtual interface | P16–20 | 读笔记 §3.3/§3.4，再看 2.2.4。**这是第一道坎**，慢点读 |
| ⑥ | 2.3.1 transaction | P20–23 | 对照 [my_transaction.sv](my_transaction.sv) + 笔记 §4.1 |
| ⑦ | 2.3.2 env | P23–25 | 对照 [my_env.sv](my_env.sv) + 笔记 §4.2/§4.3 |
| ⑧ | 2.3.3 monitor | P25–28 | 对照 [my_monitor.sv](my_monitor.sv) + 笔记 §4.4 |
| ⑨ | 2.3.4 agent | P28–32 | 对照 [my_agent.sv](my_agent.sv) + 笔记 §4.5 |
| ⑩ | 2.3.5 reference model | P32–36 | 对照 [my_model.sv](my_model.sv) + 笔记 §4.6/§5 |
| ⑪ | 2.3.6 scoreboard | P36–38 | 对照 [my_scoreboard.sv](my_scoreboard.sv) + 笔记 §4.7 |
| ⑫ | 2.3.7 field_automation | P38–41 | 对照 my_transaction.sv 的宏部分 + 笔记 §4.8 |
| ⑬ | 2.4.1–2.4.2 sequence | P41–48 | 对照 my_sequence/sequencer/driver + 笔记 §6（**全章核心，多花时间**） |
| ⑭ | 2.4.3 default_sequence | P48–50 | 对照 base_test.sv 的 my_case0 + 笔记 §6.4 |
| ⑮ | 2.5.1–2.5.2 测试用例 | P50–55 | 对照 base_test.sv/top_tb.sv + 笔记 §7 |

### 0.3 阅读姿势

- 双屏：一边 PDF、一边本目录代码，**读到任何类名就跳到对应文件找一遍**；
- 卡住时先问「这个组件/机制**解决了什么问题**」，再抠语法细节——UVM 的每个机制都是为了治某种乱象而生；
- 2.2 的演进版代码不必逐行抠（最终形态在 2.3 之后），但**动机段必须读**；
- 第一轮不求全懂，phase 机制、TLM 端口体系第 4/5 章才讲透，此处会用即可。

---

## 1. 预备知识

### 1.1 验证平台是什么

DUT（Design Under Test，被测设计）是写好的 RTL。验证平台就是给 DUT 搭的「测试台架」：
**模拟真实环境给 DUT 喂数据（激励），再检查 DUT 吐出来的数据对不对（比对）**。
类比芯片测试机（ATE）：验证平台 = 仿真世界里的 ATE，只是跑在你的仿真器里。

### 1.2 UVM 是什么

UVM（Universal Verification Methodology）不是一个工具，而是**一套用 SystemVerilog class 写成的类库 + 使用规约**。它回答一个问题：「验证平台该由哪些部件组成、部件之间怎么连接、怎么启动和收尾」。大家都按同一套方法写，平台就能互换、复用、接力。

### 1.3 最小 SV 语法集（UVM 会用到的那部分）

| 语法 | 一句话解释 | 在平台里的样子 |
|------|-----------|----------------|
| `class ... endclass` | 软件对象，动态创建销毁，与 module（静态硬件）相对 | 所有 UVM 组件都是 class |
| `extends` | 继承：子类自动拥有父类的成员和方法 | `my_driver extends uvm_driver` |
| `virtual function/task` | 允许子类**重载**此方法，通过父类句柄也能调到子类实现 | phase 函数全部声明成 virtual |
| `function` vs `task` | function 必须零耗时执行完；task 可以含延时/等待事件 | build_phase 是 function，main_phase 是 task |
| `rand` + `constraint` + `randomize()` | 随机变量 + 约束求解器：randomize 在约束内给 rand 变量随机值 | transaction 的字段都是 rand |
| `post_randomize()` | randomize 成功后**自动紧随调用**的钩子函数 | 书里用它算 CRC |
| `bit [7:0] q[$]` | 队列：长度可变，push_back/pop_front，自动伸缩 | driver/monitor 攒字节流用 |
| `bit [7:0] a[]` | 动态数组：用前必须 `new[尺寸]` | unpack_bytes 的入参要求 |
| 非阻塞赋值 `<=` | 在时钟沿统一生效，模拟寄存器行为 | driver 驱动 vif.data |

### 1.4 interface 与 virtual interface（第一道坎）

**interface**：SV 专门给验证用的「信号捆扎带」——把一组相关信号（clk、valid、data…）打包成一个对象，比逐根连线清爽：

```systemverilog
interface my_if(input clk, input rst_n);
    logic [7:0] data;
    logic       valid;
endinterface
```

**问题来了**：UVM 组件全是 class（软件世界），而 interface 实例是 module 世界的静态硬件对象。**class 里不能直接写 `my_if input_if(...)` 这种实例化语句**。

**解法**：class 里声明一个 `virtual my_if vif;`——「虚接口」就是**存了某个 interface 实例地址的句柄**（好比拿到外设基地址才能操作它；句柄不熟的看 [sv_class_syntax.md](sv_class_syntax.md) §二）。然后把句柄从 module 世界**递**进 class 世界，递的工具就是 config_db（见 §3.4）。

```
module 世界（静态）：  top_tb 里实例化 input_if/output_if，连到 DUT
                            │  uvm_config_db::set 递句柄
class 世界（动态）：     driver/monitor 里 virtual my_if vif = get(...)
```

### 1.5 UVM 树：组件世界的户口本

所有 UVM 组件（component）组成一棵树：树根固定叫 **uvm_test_top**（run_test 创建的那个实例，不管它实际类名是啥都会被改名成这个），往下是 env → agent → driver/monitor/sequencer。每个组件的完整路径 = 祖先名依次点连，如 `uvm_test_top.env.i_agt.drv`。config_db 传东西、打印信息的前缀，都认这棵树。

---

## 2. 平台全景（书 2.1，P7）

五个核心组件，一条**激励线**、一条**比较线**：

```
激励线：sequence ──产生──> transaction ──> sequencer ──> driver ──> DUT 端口
                                                              │
比较线：  i_mon(偷看输入) ──> reference model(算期望) ──┐         │
          (挂在输入侧)                                  scoreboard(compare)
          o_mon(采输出) ────────────────────────────────┘
          (挂在输出侧)        DUT ──> txd
```

| 组件 | 基类 | 职责 | 生命周期 |
|------|------|------|----------|
| driver | `uvm_driver#(T)` | 把 transaction 翻译成端口级时序驱动给 DUT | 整个仿真都在 |
| monitor | `uvm_monitor` | 反向翻译：盯着端口，把信号攒回 transaction | 整个仿真都在 |
| reference model | `uvm_component` | 用高级语言（无延时）算出「期望输出」 | 整个仿真都在 |
| scoreboard | `uvm_scoreboard` | 期望 vs 实际，逐笔比较，裁决对错 | 整个仿真都在 |
| sequencer | `uvm_sequencer#(T)` | sequence 和 driver 之间的仲裁管道 | 整个仿真都在 |
| transaction | `uvm_sequence_item` | 数据本身（一帧以太网包） | **有生老病死** |
| sequence | `uvm_sequence#(T)` | 批量产生 transaction 的脚本 | 发完即亡 |

**为什么要 i_mon 和 o_mon 两个 monitor？为什么 driver 不直接把数据递给 model？**（书 P27）
① 大项目里 driver 与 monitor 常由不同人按协议各写各的，两份独立实现对协议的理解可以互相校验；② monitor 是纯粹的「协议观察者」，不掺激励策略，将来换 DUT/换环境时 **monitor+agent 整包复用**，而 driver 与激励耦合通常要重写。

**component / object 二分法（贯穿全章的总纲，书 P21–22）**
- **一辈子都在**、要挂到 UVM 树上的 → 派生自 `uvm_component`（driver/monitor/model/scb/sequencer/env/test/agent），注册用 `` `uvm_component_utils ``，创建必须 `xxx::type_id::create("名字", parent)`（parent 是树上的爹）；
- **有生命周期**、不占树结点的（transaction、sequence）→ 派生自 uvm_object 系，注册用 `` `uvm_object_utils ``，创建 `type_id::create("名字")` **不传 parent**。
- 记忆：**树上的叫 component，树外飞来飞去的数据叫 object**。只有 component 能当树结点。

---

## 3. 四大基础设施（书 2.2）

书 2.2 先搭一个只有 driver 的裸平台，过程中被迫引入四个机制——每个机制都是被「痛点」逼出来的：

### 3.1 factory 机制（2.2.2）

- **做法**：类内部写一行 `` `uvm_component_utils(my_driver) ``（背后宏展开帮你注册了一大堆代码），之后创建实例不写 `d = new(...)`，改写 `d = my_driver::type_id::create("drv", this);`
- **create vs new**：new 是直接造对象；create 是**先向 factory 下单，由 factory 造**。factory 造的对象才有资格被 factory 眼里的「替换名单」换掉。
- **为什么多此一举**：现在看不出差别，到 ch8 的 factory 重载（override）就明白了——测试时想把 `my_driver` 整体换成 `err_driver` 注错，只要一句 `set_type_override`，所有 `type_id::create` 出来的实例自动变成 err_driver。**用 new 写死的地方 factory 无能为力**。
- 要点：**UVM 里所有类一律注册 + type_id::create，不问为什么**。

### 3.2 objection 机制（2.2.3）

- **痛点**：仿真什么时候结束？Verilog 时代靠 `$finish`。UVM 里 phase 是自动推进的，没人拦着 main_phase 会瞬间跑完——所以要有个「举手机制」：**有人举手（raise_objection）phase 就不结束，全部放下（drop_objection）才切换**。
- 用法（配对出现）：
  ```systemverilog
  task my_driver::main_phase(uvm_phase phase);
      phase.raise_objection(this);   // 开工前举手
      ... 干活 ...
      phase.drop_objection(this);    // 收工放下
  endtask
  ```
- 全局 objection 计数是所有人 raised 之和；**降到 0 的瞬间 phase 立即结束**。
- 伏笔：本书 1.1d 的习惯是让 sequence 挂 objection；我们平台用了 1.2 的自动机制 + drain time，见 §6.4 和 §9 坑③④。

### 3.3 virtual interface（2.2.4）——复述 §1.4 的落地三步

1. top_tb（module）里实例化接口并连 DUT：`my_if input_if(clk, rst_n);`
2. top_tb 里用 config_db 把句柄**存**起来（存的时候用字符串地址标注「给谁」）；
3. driver/monitor 在 build_phase 里**取**出来：
   ```systemverilog
   virtual function void build_phase(uvm_phase phase);
       super.build_phase(phase);
       if(!uvm_config_db#(virtual my_if)::get(this, "", "vif", vif))
           `uvm_fatal("my_driver", "virtual interface must be set for vif!!!")
   endfunction
   ```
   取失败就 `uvm_fatal` 立刻死——平台没有接口等于白搭，早死早超生，别带病运行。

### 3.4 config_db 的参数语义（面试常问）

```systemverilog
uvm_config_db#(类型)::set( 视野,   路径,            字段名, 值 );
uvm_config_db#(类型)::get( 视野,   路径,            字段名, 值 );  // get 的值是输出参数
```

- **set 的「视野+路径」**合起来定位收件人：视野 `null` → 路径是**绝对路径**（从 `uvm_test_top` 写起）；视野 `this`（在某个 component 里）→ 路径是**相对自己的相对路径**（省掉 uvm_test_top 前缀）。top_tb 是 module 没有 this，只能用 null + 绝对路径（书 P48 明确讲了这一对用法）。
- **get 的路径**：一般写 `""`，表示「发给我自己」（在本组件内取）。
- 完整例子（top_tb）：
  ```systemverilog
  uvm_config_db#(virtual my_if)::set(null, "uvm_test_top.env.i_agt*", "vif", input_if);
  ```
- **坑伏笔**：路径其实是**正则/通配语义**——`i_agt` 精确名匹配不到 `i_agt.drv`，要写 `i_agt*`（详见 §9 坑②，原理在书 3.5.7/P94）。

---

## 4. 逐组件精读（书 2.3）

### 4.1 transaction（2.3.1 → [my_transaction.sv](my_transaction.sv)）

**是什么**：激励的基本单位。本例是标准以太网帧：

| 字段 | 宽度 | 含义 |
|------|------|------|
| dmac | 48 bit | 目的 MAC 地址 |
| smac | 48 bit | 源 MAC 地址 |
| ether_type | 16 bit | 上层协议类型 |
| pload | 动态数组 | 载荷数据，46~1500 字节 |
| crc | 32 bit | 校验值 |

顺带一个协议常识：以太网最短帧 64 字节 = 6(dmac)+6(smac)+2(type)+**46**(最小pload)+4(crc)，这就是 constraint 写 46~1500 的出处。

代码要点（对照清单 2-23 与本目录文件）：
```systemverilog
class my_transaction extends uvm_sequence_item;   // ① 基类必须是它
    rand bit [47:0] dmac;                          // ② 激励字段都是 rand
    ...
    rand byte pload[];
    constraint pload_cons { pload.size >= 46; pload.size <= 1500; }  // ③ 约束
    function void post_randomize();                // ④ 随机化后自动调
        crc = calc_crc;
    endfunction
    `uvm_object_utils(my_transaction)              // ⑤ object 注册（不是 component_utils）
```
- ①：**只有 uvm_sequence_item 的子孙才能上 sequence 这套流水线**——sequence 机制内部按这个基类做类型处理，继承错了 uvm_do 直接编不过。
- ③：约束随机 = 「在这批合法值里随机挑一个」，比手写 directed 激励覆盖面大得多，这是 SV 相对 Verilog 验证最大的进步之一。
- ⑤：transaction 是数据不是组件，用 `uvm_object_utils`（对照 §2 的二分法）。

### 4.2 env：容器（2.3.2 → [my_env.sv](my_env.sv)）

- **痛点**（书 P23 讲得很直白）：driver、monitor、model… 这么多组件在哪创建？`run_test` 只能创建**一个**实例（树根），组件全造在 top_tb 里又脱离了 UVM 体系。解法：造一个容器类把它们全装进去，`run_test` 只创建容器——这个容器就是 **env**。
- `run_test("my_case0")` 创建的树根实例名固定是 **uvm_test_top**，env 是它的孩子。config_db 绝对路径全部以 uvm_test_top 开头，出处在此。

### 4.3 组件实例化铁律（书 P31–32，UVM_FATAL [ILLCRT]）

1. component 的 `type_id::create` **只能在 build_phase 里做**（new 里也行，见第 3 条），在其他 phase 里会直接 fatal：
   `UVM_FATAL ... [ILLCRT] It is illegal to create a component after the build phase has ended`
2. build_phase 的执行顺序是**树根 → 树叶**：先 env 的 build（造出 agent），再 agent 的 build（造出 driver/monitor）——正好保证造孩子时爹已经存在。connect_phase 则相反（§5.3）。
3. 技术上也可以写在 new 里（清单 2-39），但**强烈不推荐**：在 new 里创建的话，父组件 build_phase 里对它的直接赋值（如 `i_agt.is_active = UVM_ACTIVE`）全部无效——因为 new 比赋值先执行，is_active 的改动来不及生效。**正解是用 config_db 传参数**（清单 2-40，本平台的 agent 正是 config_db 取 is_active）。
4. 要点：**所有组件一律 build_phase 里 create，参数一律 config_db 传**。

### 4.4 monitor（2.3.3 → [my_monitor.sv](my_monitor.sv)）

driver 的镜像：driver 把 transaction 拆成字节按拍打出去；monitor 把总线上的字节按拍收回来拼成 transaction。

```systemverilog
task my_monitor::main_phase(uvm_phase phase);
    my_transaction tr;
    while(1) begin                 // 永动循环：monitor 一辈子都在看
        tr = new("tr");            // 每包一个新对象（一包一命）
        collect_one_pkt(tr);
    end
endtask

task my_monitor::collect_one_pkt(my_transaction tr);
    bit[7:0] data_q[$];            // 队列攒字节
    while(1) begin                 // ① 等包头：valid 拉高才开工
        @(posedge vif.clk);
        if(vif.valid) break;
    end
    while(vif.valid) begin         // ② valid 期间逐字节收
        data_q.push_back(vif.data);
        @(posedge vif.clk);
    end
    // ③ 队列 → 动态数组（unpack_bytes 只吃动态数组）
    // ④ tr.pload = new[data_size - 18];   先给 pload 定长！
    // ⑤ tr.unpack_bytes(data_array);      一句话还原整帧
endtask
```
- **④ 是隐藏坑**：pload 是动态数组字段，unpack 前必须先 `new` 定长，否则 unpack 不知道往里塞多少字节。`data_size - 18` 的 18 = 6(dmac)+6(smac)+2(type)+4(crc)。
- monitor 基类是 `uvm_monitor`（其实是 uvm_component 的空壳别名，语义标注「我只看不改」）。

### 4.5 agent（2.3.4 → [my_agent.sv](my_agent.sv)）

**agent = 同一种协议的 sequencer + driver + monitor 打包**。不同 agent 代表不同协议（如 ahb_agent、eth_agent），是**复用的基本单元**——换个项目，把 eth_agent 整个文件夹拷走就能用。

```systemverilog
class my_agent extends uvm_agent;      // is_active 是 uvm_agent 自带的成员
    my_sequencer sqr;
    my_driver    drv;
    my_monitor   mon;
    uvm_analysis_port #(my_transaction) ap;   // 对外广播口（§5.2 讲）
    ...
    function void build_phase(uvm_phase phase);
        ...
        if(is_active == UVM_ACTIVE) begin
            sqr = my_sequencer::type_id::create("sqr", this);
            drv = my_driver::type_id::create("drv", this);
        end
        mon = my_monitor::type_id::create("mon", this);   // monitor 永远要
    endfunction
```
- `is_active`：类型 `uvm_active_passive_enum`（`typedef enum bit {UVM_PASSIVE=0, UVM_ACTIVE=1}`，清单 2-35），**默认 UVM_ACTIVE**。
- **ACTIVE**（激励+监视，DUT 输入侧用）vs **PASSIVE**（只监视，DUT 输出侧用——输出侧没人去驱动，要 driver 干嘛）。
- 本平台：i_agt = ACTIVE，o_agt = PASSIVE，由 env 用 config_db 设定。

### 4.6 reference model（2.3.5 → [my_model.sv](my_model.sv)）

- **职责**：和 DUT 做一模一样的事，但用纯软件方式（零延时）——它的输出是「黄金期望值」，scoreboard 拿它当标准答案。
- 本例 DUT 是打一拍直通，model 也只是复制转发：
  ```systemverilog
  task my_model::main_phase(uvm_phase phase);
      my_transaction tr, new_tr;
      while(1) begin
          port.get(tr);              // 从 fifo 拿 monitor 采到的输入
          new_tr = new("new_tr");
          new_tr.copy(tr);           // 复制出新对象
          ap.write(new_tr);          // 广播给 scoreboard 当期望值
      end
  endtask
  ```
- **为什么 copy 一份再转发**：tr 马上还要被别处用/改，直接把引用递出去，上下游会改同一份对象——经典 aliasing bug。copy 由 field_automation 免费提供（§4.8）。
- 真实项目里 model 可能是 C/DPI 参考模型、也可能是纯 SV 行为模型——复杂度全在这，但**对外接口永远就是一进一出**，这是 TLM 分层的好处。

### 4.7 scoreboard（2.3.6 → [my_scoreboard.sv](my_scoreboard.sv)）

要同时吃**两路**数据（期望来自 model、实际来自 o_mon），一个组件两个口 → 用 `uvm_analysis_imp_decl` 声明两个带后缀的 imp：

```systemverilog
`uvm_analysis_imp_decl(_monitor)      // 生成 uvm_analysis_imp_monitor 类
`uvm_analysis_imp_decl(_model)        // 生成 uvm_analysis_imp_model 类

class my_scoreboard extends uvm_scoreboard;
    my_transaction expect_queue[$];   // 期望值排队
    uvm_analysis_imp_monitor #(my_transaction, my_scoreboard) monitor_imp;  // 实际
    uvm_analysis_imp_model   #(my_transaction, my_scoreboard) model_imp;    // 期望

    function void write_model(my_transaction tr);     // 期望来了：入队
        expect_queue.push_back(tr);
    endfunction

    function void write_monitor(my_transaction tr);   // 实际来了：出队比较
        my_transaction tmp;
        if(expect_queue.size() > 0) begin
            tmp = expect_queue.pop_front();
            if(tr.compare(tmp)) `uvm_info(...)
            else `uvm_error(...)              // 比不上：报错+打印两笔
        end
        else `uvm_error("expect_queue is empty")  // 期望没有却有输出：也是 bug
    endfunction
```
- 书上原版用 fork 两个进程 + 两个 blocking_get_port（清单 2-50），效果相同；imp 写法少两组 fifo 连线，是 4.3.2 的官方多 imp 方案。
- **「期望必先到」的隐含前提**：model 零延时、DUT 有延时，所以同 一笔数据期望总先排队。scoreboard 的正确性建立在这个时序差上——面试可能问「如果 model 有延时怎么办」（答：expect_queue 会空报错，需在 model 侧对齐时序或 scb 侧等待）。
- 比较用的 `compare()` 来自 field_automation（§4.8）。

### 4.8 field_automation 机制（2.3.7）

在 transaction 里把「utils 注册」换成带 begin/end 的版本，逐字段登记：

```systemverilog
`uvm_object_utils_begin(my_transaction)
    `uvm_field_int(dmac,       UVM_ALL_ON)
    `uvm_field_int(smac,       UVM_ALL_ON)
    `uvm_field_int(ether_type, UVM_ALL_ON)
    `uvm_field_array_int(pload, UVM_ALL_ON)   // 动态数组用 array 版宏
    `uvm_field_int(crc,        UVM_ALL_ON)
`uvm_object_utils_end
```

登记后**免费获得五个函数**，不用再手写：

| 函数 | 作用 | 谁在用 |
|------|------|--------|
| `copy()` | 逐字段深拷贝 | model |
| `compare()` | 逐字段比较，返回 bit | scoreboard |
| `print()` | 逐字段打印 | 调试到处用 |
| `pack_bytes()` | transaction → 字节流 | driver |
| `unpack_bytes()` | 字节流 → transaction | monitor |

书 2.3.3–2.3.6 先让你手写 my_print/my_copy/my_compare，2.3.7 再全部推翻——是刻意让你先体会手写的痛，才知道这组宏的价值。

**两条规则（都是面试考点）**：
1. **pack/unpack 的字节顺序 = uvm_field 宏的书写顺序**（清单 2-56 专门演示了调换顺序的后果）。线上协议顺序、driver 的 pack、monitor 的 unpack 三者必须一致，改宏顺序 = 改「线路协议」。
2. 第二参数是**控制位**：`UVM_ALL_ON` 表示所有操作都对它生效，还可以按位组合（如 `UVM_NOCOMPARE` 不参与比较）——全表在书 3.3.1（P69）。

---

## 5. TLM 通信专题（2.3.5/2.3.6 里埋的线，第 4 章展开）

组件之间传 transaction 不用全局变量、不用层次引用硬抠，用 **TLM（Transaction Level Modeling）端口**——类比「插头-插座-设备」：

| 端口 | 角色 | 阻塞性 | 本平台谁在用 |
|------|------|--------|--------------|
| `uvm_analysis_port`（port） | 插头（广播方） | 非阻塞 write，一对多 | i_mon.ap / o_mon.ap / mdl.ap |
| `uvm_blocking_get_port`（port） | 主动拉取的插头 | 阻塞 get | mdl.port |
| `uvm_analysis_imp` | 设备（被动接收方） | 收 write 调用 | scb 的两个 imp |
| `uvm_tlm_analysis_fifo` | 中转仓库 | 内含 analysis_export + blocking_get_export | agt_mdl_fifo |

### 5.1 为什么 mon→model 之间必须垫一个 fifo？（书 P35，经典面试题）

analysis_port 的 `write()` 是**非阻塞**的：喊一嗓子就走，不等对方接。
而 model 的 blocking_get_port 是「我忙我的，想拿了才来拿」。
一头是「喊完就走」，另一头是「想拿才拿」——**喊的瞬间对方恰好没拿，数据就丢了**。
fifo 就是中间的货架：`mon.ap → fifo.analysis_export`（往货架上放），`mdl.port → fifo.blocking_get_export`（想拿就来拿），write 永不阻塞、get 永不丢数。

### 5.2 连线（env 的 connect_phase，[my_env.sv](my_env.sv)）

```systemverilog
function void my_env::connect_phase(uvm_phase phase);
    i_agt.ap.connect(agt_mdl_fifo.analysis_export);   // 输入侧 → 货架
    mdl.port.connect(agt_mdl_fifo.blocking_get_export); // model 从货架拿
    mdl.ap.connect(scb.model_imp);                    // 期望 → scb
    o_agt.ap.connect(scb.monitor_imp);                // 实际 → scb
endfunction
```

### 5.3 agent 的 `ap = mon.ap` 是什么（书 P36）

不是新建端口，是**句柄转发**：让 agent 拿出成员 `ap` 指向内部 monitor 的 ap，外部直接连 `i_agt.ap` 等于连到 `i_agt.mon.ap`——对外隐藏内部结构（agent 封装性的体现）。
**为什么安全**：connect_phase 的执行顺序是**树叶 → 树根**（和 build 相反！），agent 的 connect（做 `ap = mon.ap`）先于 env 的 connect（用 `i_agt.ap` 连线），轮到 env 时句柄早已赋好，不会是空句柄。**build 从根到叶、connect 从叶到根**，成对记忆。

---

## 6. sequence 机制（书 2.4，全章核心）

### 6.1 动机与三角色（P41–44）

改造前（2.2–2.3）激励是 driver 自己 `randomize` 出来的——**产生激励和驱动激励焊死在一起**。想换一套激励策略就得改 driver；想复用 driver 到别的项目也难。
sequence 机制把「**产生**激励」从 driver 身上剥离：driver 从此只认 transaction 来了就打，不打源从哪来。

书 P44 的比喻：
- **sequence = 弹夹**（uvm_object；body() 是主任务，装着产弹逻辑）
- **sequencer = 枪**（uvm_component；挂在 agent 里，负责仲裁）
- **transaction = 子弹**

sequence 不属于验证平台的结构（图 2-10 里画在 env 外面、虚线）——它是**被启动后临时存在的对象**，弹打完就消亡。这正是 §2 二分法里 object 的特征。

```systemverilog
class my_sequencer extends uvm_sequencer #(my_transaction);  // 枪：参数=子弹类型
class my_driver    extends uvm_driver    #(my_transaction);  // 同参数 → 对得上话
class my_sequence  extends uvm_sequence  #(my_transaction);  // 弹夹：参数=子弹类型
```
- driver 参数化后白得一个成员 `req`（类型即 my_transaction），不用自己声明。

### 6.2 uvm_do 与握手（P45–46）

sequence 的 body：
```systemverilog
virtual task body();
    repeat(10) `uvm_do(m_trans)
endtask
```
`` `uvm_do(m_trans) `` 一句干三件事：**① 创建 my_transaction 实例 ② 随机化（受 constraint 约束）③ 送给 sequencer**。
手写等价式是 `start_item(m_trans); assert(m_trans.randomize()); finish_item(m_trans);`（ch6 展开）。

**sequencer 的仲裁**（P45）：它同时盯着两边——
1. 只有 sequence 想发 → 等 driver 来申请；
2. 只有 driver 来申请 → 等 sequence 提请求；
3. 两边都在 → 立即撮合成交。

**握手为什么要 item_done**（P46，面试爱问）：sequencer 把 transaction 递给 driver 后**自己还留了一份副本**；driver 干完活调 `item_done()`，sequencer 才确认送达、销毁副本。万一传输中出岔子，sequencer 能凭副本重发——**可靠性握手机制**。
同时 `uvm_do` 会**阻塞到 item_done 才返回**，所以 body 里 10 个 uvm_do 是严格串行的：上一颗弹打完才装下一颗。

### 6.3 driver 侧标准循环（清单 2-65 → [my_driver.sv](my_driver.sv)）

```systemverilog
task my_driver::main_phase(uvm_phase phase);
    vif.data  <= 8'b0;
    vif.valid <= 1'b0;
    while(!vif.rst_n) @(posedge vif.clk);   // 等复位释放
    while(1) begin
        seq_item_port.get_next_item(req);   // 阻塞申请：没弹就等着
        drive_one_pkt(req);                 // 打出去
        seq_item_port.item_done();          // 报告：打完了
    end
endtask
```
- `while(1)` 永动：driver 只驱动不产生，有弹就打、没弹就等，和 monitor/model/scb 的永动哲学一致。
- `get_next_item`（阻塞）vs `try_next_item`（非阻塞，没弹立刻拿 null 返回，清单 2-68）：后者更贴近真实总线行为（没数据时总线保持空闲态），前者代码最简单，先用它就行。

### 6.4 sequence 的启动与 objection（2.4.2 末 + 2.4.3，**1.1d vs 1.2 分水岭**）

**方式一：手动 start**（清单 2-66，教学演示用）
```systemverilog
task my_env::main_phase(uvm_phase phase);
    phase.raise_objection(this);
    seq = my_sequence::type_id::create("seq");
    seq.start(i_agt.sqr);          // 参数=挂到哪把枪上
    phase.drop_objection(this);
endtask
```

**方式二：default_sequence**（实际项目主力，本平台采用）
```systemverilog
// 在某个 component 的 build_phase 里：
uvm_config_db#(uvm_object_wrapper)::set(this,
    "env.i_agt.sqr.main_phase",      // 注意：路径末尾必须带 phase 名！
    "default_sequence",
    my_sequence::type_id::get());    // 类型固定 uvm_object_wrapper
```
- 末尾的 main_phase 表示「在这个 phase 开打」；`uvm_object_wrapper` 是 UVM 的规定写法，照抄即可（P49）。
- sequencer 自己会去 get 这条配置（UVM 内部代劳），不用手写 get。

**objection 谁来挂？——书 P49–50 的 starting_phase 故事：**
- **UVM 1.1d（书正文）**：sequencer 启动 default_sequence 前自动执行 `seq.starting_phase = phase`，sequence 在 body 里手写：
  ```systemverilog
  if(starting_phase != null) starting_phase.raise_objection(this);
  ... `uvm_do ...
  if(starting_phase != null) starting_phase.drop_objection(this);
  ```
- **UVM 1.2（我们实际在用）**：书 P50 脚注官方盖章「UVM1.2 优化了 starting_phase 的功能，其使用方式也有所变更」——1.2 **不再给 default_sequence 设置 starting_phase**，书上写法的 starting_phase 恒为 null，两行 if 被静默跳过 → **没人举手 objection，main_phase 瞬间结束**（我们踩的坑③，现象是平台 0 活动）。
- **1.2 正解**：sequence 的 new 里 `set_automatic_phase_objection(1);`，由 UVM 在启动时自动 raise/drop。本平台 [my_sequence.sv](my_sequence.sv) 就是这个写法。
- 面试可以这么说：「1.1d 依赖 starting_phase 手动 raise/drop，1.2 改用 set_automatic_phase_objection，书上写法在 1.2 下会静默失效」。

---

## 7. 测试用例与启动流程（书 2.5）

### 7.1 base_test：真正的树根（2.5.1 → [base_test.sv](base_test.sv)）

实际平台树根不是 env，而是 `uvm_test` 的派生类（本例 base_test）：

```systemverilog
class base_test extends uvm_test;
    my_env env;
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = my_env::type_id::create("env", this);   // env 成了树根的孩子
    endfunction
    function void report_phase(uvm_phase phase);      // 全部 phase 跑完后结算
        server = uvm_report_server::get_server();
        err_num = server.get_severity_count(UVM_ERROR);
        if (err_num != 0) $display("TEST FAILED...");
        else              $display("TEST PASSED!!!");
    endfunction
```
- **report_phase** 是 UVM 内建 phase，所有 main 类 phase 结束后执行，适合做「终审判决」——按 UVM_ERROR 计数判定 PASS/FAILED。
- base_test 还常干两件事（书 P51）：设全局超时退出时间、用 config_db 给平台配默认参数。

### 7.2 测试用例差异化模式（2.5.2 → my_case0/my_case1）

- 一个 case = base_test 的一个派生类，**平台复用、激励差异化**：case 只重载 build_phase，换掉 default_sequence 指的 sequence 类；
- 差异激励用 `` `uvm_do_with(m_trans, { m_trans.pload.size() == 60; }) `` 内联约束（case1 发短包，清单 2-77）；
- 这样加新 case 不碰平台代码——「后加的 case 不影响已有 case」（书 P52 的原话），这正是 factory+config_db 组合带来的方便。

### 7.3 启动：run_test 与 +UVM_TESTNAME（P52–55）

```systemverilog
// top_tb.sv
initial begin
    uvm_config_db#(virtual my_if)::set(null, "uvm_test_top.env.i_agt*", "vif", input_if);
    uvm_config_db#(virtual my_if)::set(null, "uvm_test_top.env.o_agt*", "vif", output_if);
    run_test("my_case0");       // 也可以 run_test() 不带参数
end
```
```bash
./simv +UVM_TESTNAME=my_case0     # 命令行选 case，改 case 不用重编译
```
- 书清单 2-81 写的 `+UVM_TEST_NAME` 是**笔误**，实际 plusarg 是 `+UVM_TESTNAME`（无下划线）——本平台 Makefile 的写法已验证可用。
- `run_test()` 不带参时，UVM 从命令行 `+UVM_TESTNAME=xxx` 找类名，经 factory 创建实例——**同一个 simv 换 plusarg 就能跑不同 case**（图 2-12 的流程）。

### 7.4 一条完整时间线（把全章串起来）

```
t=0 仿真器启动
 │  top_tb 的 initial：clk/rst_n 开始翻转；set 两条 vif；run_test("my_case0")
 │
 ├─ UVM 接管：按 UVM_TESTNAME 经 factory 创建树根（my_case0，改名 uvm_test_top）
 │
 ├─ build_phase（树根→树叶）：base_test 造 env → env 造 i_agt/o_agt/mdl/scb
 │    → i_agt 造 sqr/drv/mon，o_agt 只造 mon；每个组件 get 到自己的 vif/is_active
 │
 ├─ connect_phase（树叶→树根）：agent 内 drv↔sqr 连线、ap=mon.ap 转发
 │    → env 把 fifo、scb 的两路 imp 全部接好
 │
 ├─ （中间还有几个function phase，第5章讲，本平台没用到）
 │
 ├─ main_phase（各组件并发）：
 │    sqr 启动 default_sequence → 自动 raise objection
 │      sequence: `uvm_do ×10 → 随机出 10 帧排队交给 sqr
 │      drv:      get_next_item → pack_bytes → 逐字节驱动 DUT → item_done ×10
 │      i_mon:    偷看输入，10 帧 → fifo → mdl: copy 出 10 份期望 → scb 入队
 │      DUT:      打一拍 → o_mon: 采 10 帧 → scb 出队 compare ×10
 │      sequence 打完：自动 drop objection
 │      │  ← drain time 多等 1us，让最后一路数据走完（§9 坑④）
 │
 ├─ objection 计数归零 → main_phase 结束，后续 phase 依次跑完
 │
 ├─ report_phase：数 UVM_ERROR → 打印 TEST PASSED!!!
 │
 └─ 所有 phase 结束 → 仿真退出
```

---

## 8. phase 执行顺序速查表

| phase | 类型 | 执行顺序 | 干什么 | 要点 |
|-------|------|----------|--------|----------|
| build_phase | function | **树根 → 树叶** | create 组件、get config_db 资源 | 实例化只能在这 |
| connect_phase | function | **树叶 → 树根** | 接 TLM 端口、句柄转发 | 连线只能在这 |
| main_phase | task | 各组件**并发**（顺序不定） | 干活主战场：驱动/采集/比较 | 永动 while(1) |
| report_phase | function | main 全结束后 | 统计错误、判 PASS/FAILED | 结算在这 |

**两条铁律**：
1. 组件的 create 只能出现在 build_phase（或 new），否则 `UVM_FATAL [ILLCRT]`（§4.3）；
2. task phase（如 main_phase）各结点并发执行，**不要依赖两个组件 main 里的先后顺序**——顺序保证一律用 TLM 数据流表达（数据到了自然触发下一步）。

---

## 9. 实战坑记录（本平台搭建时真实踩过）

| # | 现象 | 根因 | 修法 | 原理书页 |
|---|------|------|------|----------|
| ① | `Error-[URMI] Unresolved modules: dut` | 编译清单漏了 dut.sv | Makefile 编译列表补全 | — |
| ② | t=0 就 `vif` fatal；`+UVM_CONFIG_DB_TRACE` 显示 SET 成功 / GET failed | **config_db 路径是正则语义**：set 精确名 `i_agt` 匹配不到组件全名 `i_agt.drv` | set 路径写通配 `i_agt*` / `o_agt*` | 3.5.7（P94） |
| ③ | 平台 0 活动，t=0 就结束（$finish 来自 uvm_root） | **UVM 1.2 不再给 default_sequence 设 starting_phase**，书上的 raise/drop 因 null 被静默跳过，无人举 objection | sequence 的 new 里 `set_automatic_phase_objection(1)` | P50 脚注、6.5.4 |
| ④ | 「10 驱动只比较 9」的假通过：objection 撤销时最后一笔还在 DUT→o_mon→scb 路上 | objection 归零瞬间 phase 即结束，不等数据走完 | base_test 的 main_phase 里 `phase.phase_done.set_drain_time(this, 1us)` | 5.2.4（P154） |
| ⑤ | set 与 run_test 分居两个 initial 时 vif 仍 fatal | SV **不保证不同 initial 块的执行顺序**，run_test 可能先跑 | set 与 run_test 合并到同一 initial | — |

诊断工具一句话：config_db 类问题第一反应 `+UVM_CONFIG_DB_TRACE` 跑一遍，SET/GET 对照一目了然。

---

## 10. 与第 3 章的衔接

第 2 章「会用」，第 3 章（书 P56–99 / PDF P69–112）讲「为什么」：
- **3.1–3.2**（P56–69）：uvm_component/uvm_object 完整类体系 + UVM 树与层次函数——§2 二分法的完整版；
- **3.3**（P69–76）：field automation 全部宏、标志位、与 union/if 结合——§4.8 的完整版；
- **3.4**（P76–85）：打印信息控制（verbosity 阈值、UVM_ERROR 计数结束仿真、导出日志文件）；
- **3.5**（P85–99）：**config_db 全解**——3.5.7「对通配符的支持」就是坑②的官方原理，3.5.10 config_db 调试 = `+UVM_CONFIG_DB_TRACE` 的用法。
