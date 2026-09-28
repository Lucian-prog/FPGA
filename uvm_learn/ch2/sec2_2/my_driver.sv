// my_driver.sv —— 2.2 复现最终版（对应书上 2.2.4 结束时的形态）
// 演进过程：v1 普通 class → v2 factory + run_test → v3 objection → v4 virtual interface
// 每一版引入了什么、为什么，见 sec2_2_rebuild.md

`include "uvm_macros.svh"
import uvm_pkg::*;

// driver：UVM 里负责"把数据翻译成端口时序"的组件。
// 2.2 阶段它就是整个平台（树根），由 run_test 直接创建。
class my_driver extends uvm_driver;

    // v4 引入：存 interface 实例地址的句柄（好比外设基地址，拿到才能操作）。
    // virtual 的含义：class 是软件世界，不能直接引用 module 世界里的接口实例，
    // 只能通过这种"虚接口"句柄去操作它。句柄本身由 config_db 递进来。
    virtual my_if vif;

    // v2 引入：factory 注册。宏展开后，run_test("my_driver") 才能创建出本类实例。
    `uvm_component_utils(my_driver)

    // UVM 约定：组件的 new 必须是 name + parent 两个参数，
    // factory 创建实例时按这个签名调用。不按这个签名写，注册宏编译不过。
    function new(string name, uvm_component parent);
        super.new(name, parent);
        `uvm_info(get_type_name(), "new is called", UVM_LOW)
    endfunction

    // v4 引入：build_phase 是 UVM 树从根到叶依次执行的构建阶段，适合"取配置"。
    // 对 2.2 的平台来说树上只有树根自己，build_phase 就只执行这一次。
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // 从 config_db 取 vif。get 失败直接 fatal：
        // 没有 interface 的 driver 什么都驱动不了，带病运行没有意义。
        if (!uvm_config_db#(virtual my_if)::get(this, "", "vif", vif))
            `uvm_fatal(get_type_name(), "virtual interface 'vif' must be set")
    endfunction

    // v1 引入骨架，v3 加 objection，v4 加真实驱动。
    // main_phase 是 task phase，主要工作都在这里做；
    // raise/drop 之间的这段时间就是本阶段实际的时长。
    virtual task main_phase(uvm_phase phase);
        phase.raise_objection(this);    // v3：开工前举手，main_phase 别结束
        `uvm_info(get_type_name(), "main_phase is called", UVM_LOW)

        vif.valid <= 1'b0;
        while (!vif.rst_n)              // 等复位释放（rst_n 低电平是复位态）
            @(posedge vif.clk);
        drive_one_pkt();

        repeat (10) @(posedge vif.clk); // 帧发完后空跑几拍，波形好看些
        phase.drop_objection(this);     // v3：收工放下，允许 phase 结束
    endtask

    // 组一个最小以太网帧并逐字节驱动出去。
    // 注意：2.2 阶段还没有 transaction，组包直接发生在 driver 里——
    // "产生激励"和"驱动激励"焊死在一起，这正是 2.4 sequence 机制要解决的问题。
    task drive_one_pkt();
        bit [7:0] pkt[];    // 一帧的全部字节，按发送顺序排好（动态数组）
        int unsigned idx;
        int unsigned pload_len;

        pload_len = 10;                        // 载荷长度（真实以太网最短 46，演示从简）
        pkt = new[6 + 6 + 2 + pload_len + 4];  // dmac + smac + type + pload + crc

        for (idx = 0; idx < 6; idx++) begin
            pkt[idx]     = 8'h11 + idx;        // dmac 6 字节，示例值
            pkt[6 + idx] = 8'h22 + idx;        // smac 6 字节，示例值
        end
        pkt[12] = 8'h08;                       // 帧类型 16'h0800（示意）
        pkt[13] = 8'h00;
        for (idx = 0; idx < pload_len; idx++)
            pkt[14 + idx] = idx[7:0];          // 载荷：0,1,2,...

        // CRC32 本该按算法算出，书上未展开，这里填固定占位值
        pkt[14 + pload_len + 0] = 8'h12;
        pkt[14 + pload_len + 1] = 8'h34;
        pkt[14 + pload_len + 2] = 8'h56;
        pkt[14 + pload_len + 3] = 8'h78;

        // 逐字节驱动：每个时钟沿送一个字节，valid 全程拉高
        foreach (pkt[i]) begin
            @(posedge vif.clk);
            vif.valid <= 1'b1;
            vif.data  <= pkt[i];
        end
        @(posedge vif.clk);
        vif.valid <= 1'b0;                     // 收尾：valid 拉低，总线回空闲
    endtask

endclass
