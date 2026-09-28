# SV class 语法速成（写给只会 Verilog 的你）

> 目的：读懂 UVM 代码需要的最小 SystemVerilog class 语法集。每条都从 Verilog 类比起。
> 看到没讲过的语法先回来查这篇，不用去翻 LRM。

## 一、class 和 module 是两个世界

| | module 世界 | class 世界 |
|---|---|---|
| 本质 | 硬件电路 | 软件对象 |
| 何时存在 | 编译/综合时就画死了 | 仿真运行时 `new` 出来 |
| 实例数量 | 例化一次就固定 | 想要几个 new 几个 |
| 内存 | 对应真实的寄存器/线网 | RAM 里一块动态分配的空间 |
| 类比 | 画在硅片上的电路 | 按母版图纸在内存里现造的一台设备 |

从学 UVM 这天起，你有另一半时间在写软件。class 的语法看着陌生，是因为它本来就是软件语法。

## 二、声明与创建：句柄与 new

把 class 定义想成一张**母版图纸**——图纸本身不是设备；`new` 是照图纸在内存里现造一台设备；**句柄**是记下这台设备地址的变量。逐行看：

```systemverilog
class my_driver;
    int a;                       // 成员变量：每个对象自己的一份

    function new(int v = 0);     // 构造函数：new 这个对象时自动执行
        a = v;
    endfunction
endclass

my_driver d1;        // ① 声明句柄——一个存地址用的变量，此刻还没有对象！
d1 = new(5);         // ② 分配内存 → 自动调 new(...) → 把地址存进句柄
my_driver d2 = new(7);
```

和 module 例化的区别：`dut u_dut(...)` 一步到位；class 是两步，句柄和对象是分开的。

- **句柄**（handle）= 存对象地址的变量。类比 CPU 访问外设：先拿到基地址才能读写它的寄存器——对象在内存里，句柄记的就是那个地址。`d2 = d1;` 复制的是**地址**，两个句柄指向**同一个**对象（两块名牌记了同一颗芯片）——这是后面 TLM 传 transaction 的基础，也是 aliasing bug 的来源。
- **null** = 地址 0，不代表任何对象。拿 null 去访问成员，仿真当场报错。

## 三、extends 与 super

```systemverilog
class my_driver extends uvm_driver;
    function new(string name, uvm_component parent);
        super.new(name, parent);   // 先执行父类的构造逻辑
        ...                        // 再初始化自己加的部分
    endfunction
endclass
```

- `extends` = 「**uvm_driver 有的我全有**，再加我自己声明的这些」。子类对象在内存里就包含一整块父类部分。
- `super` = 「把当前对象当作父类来看」的引用。`super.new(...)` 就是先跑 uvm_driver 的 new。
- 为什么必须写：uvm_driver 的 new 在干挂树、建报告路径的活，不先跑它，组件就是个黑户。**SV 规矩：父类的 new 带参数时，子类 new 里必须显式 `super.new(参数)`。**

## 四、参数默认值

```systemverilog
function new(string name = "my_driver", uvm_component parent = null);
```

等号后面的就是默认值：调用 `new()` 一个参数都不传也能跑；传了就覆盖。和 Verilog parameter 的默认值感觉像，但这是函数参数层面的语法。

## 五、function 与 task

```systemverilog
function void build_phase(uvm_phase phase);   // 零耗时：内部不允许有延时/等待
task main_phase(uvm_phase phase);             // 可耗时：可以有 @、#、等待事件
```

和 Verilog 里 function/task 的分工一致。UVM 的规矩：build/connect 这类「准备」用 function（必须立刻完成），main 这类「干活」用 task。

## 六、virtual：为什么没人调用 main_phase，它却自己跑了

```systemverilog
virtual task main_phase(uvm_phase phase);
```

`virtual` 允许子类改写（override）这个方法。机关在于**多态**：

1. uvm_driver 里本来就有个 virtual 的、空空的 main_phase；
2. UVM 的调度器手里拿的是**基类句柄**，phase 到了就通过基类句柄调 main_phase；
3. 因为方法声明是 virtual，SV 会在运行时找到「实际类型」的实现——也就是你 my_driver 里写的这份。

所以从没有一行代码写 `drv.main_phase()`，它却执行了。UVM 的每个 phase 方法都要带 virtual，少写一个，你的实现永远不被调用（这是新手经典坑）。

## 七、uvm_info：反引号开头的是编译宏

认准反引号——`` `timescale ``、`` `define `` 的那个家族，**编译期做文本替换**：

```systemverilog
`uvm_info(get_type_name(), "new is called", UVM_LOW)
//     └─标签        └─正文           └─冗余度
```

| 参数 | 意思 |
|---|---|
| 标签 | 消息归类在谁名下，日志里显示 `[my_driver]`。`get_type_name()` 是个函数，返回类名字符串（factory 注册宏免费生成的），不硬写是为了继承后自动跟随 |
| 正文 | 打印内容 |
| 冗余度 | 重要性：`UVM_LOW` 必打；`UVM_HIGH`/`UVM_DEBUG` 默认不打，加仿真选项 `+UVM_VERBOSITY=UVM_HIGH` 才显示 |

比 `$display` 强两点：全局 verbosity 开关（不改代码调打印量）、自动带时间戳/文件名/行号（所以日志里有 `my_driver.sv(24)`）。同族宏还有 `uvm_warning` / `uvm_error` / `uvm_fatal`，严重程度递增，fatal 会当场结束仿真。

## 八、v1 代码逐行翻译

```systemverilog
class my_driver extends uvm_driver;
    // 定义一个类：uvm_driver 的全部 + 下面我加的部分（§三）

    function new(string name = "my_driver", uvm_component parent = null);
        // 构造函数：new 这个对象时自动执行（§二）
        // 参数带默认值，调用时不传也行（§四）

        super.new(name, parent);
        // 先按 uvm_driver 的规矩初始化：挂树、建名字（§三）

        `uvm_info(get_type_name(), "new is called", UVM_LOW)
        // 打一条重要度 LOW 的日志：归类 my_driver，内容 "new is called"（§七）

    endfunction

    virtual task main_phase(uvm_phase phase);
        // 可耗时的主工作方法；virtual 让 UVM 调度器能通过基类句柄调到它（§五、§六）

        `uvm_info(get_type_name(), "main_phase is called", UVM_LOW)
    endtask
endclass
```

## 九、顺手记住的两个习惯

- 看到陌生函数/方法名，先猜「它是基类带来的还是本类定义的」——UVM 组件的绝大多数能力都来自继承链（uvm_driver ← uvm_component），不用背。
- 反引号开头的都是宏，展开发生在编译期；想知道 `` `uvm_info `` 展开成什么样，去 UVM 源码 `uvm_macros.svh` 里搜，但没必要——记住三参数语义就够用。
