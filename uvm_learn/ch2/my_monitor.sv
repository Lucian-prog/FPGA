// 2.3.3：monitor，从 interface 采集字节流并还原成 transaction
// i_agt / o_agt 共用同一个 monitor 类，只是挂的 interface 不同
class my_monitor extends uvm_monitor;

    virtual my_if vif;
    uvm_analysis_port #(my_transaction) ap;

    `uvm_component_utils(my_monitor)

    function new(string name = "my_monitor", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    extern virtual function void build_phase(uvm_phase phase);
    extern virtual task main_phase(uvm_phase phase);
    extern task collect_one_pkt(my_transaction tr);

endclass

function void my_monitor::build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual my_if)::get(this, "", "vif", vif))
        `uvm_fatal("my_monitor", "virtual interface must be set for vif!!!")
    ap = new("ap", this);
endfunction

task my_monitor::main_phase(uvm_phase phase);
    my_transaction tr;
    while (1) begin
        tr = new("tr");
        collect_one_pkt(tr);
        ap.write(tr);
    end
endtask

task my_monitor::collect_one_pkt(my_transaction tr);
    byte unsigned data_q[$];   // queue 收集字节流
    byte unsigned data_array[];
    int i;

    // valid 无效时等待包到来
    while (vif.valid !== 1'b1)
        @(posedge vif.clk);
    // valid 有效期间逐字节采集
    while (vif.valid === 1'b1) begin
        data_q.push_back(vif.data);
        @(posedge vif.clk);
    end

    // field automation 的 unpack：字节流还原成 transaction
    data_array = new[data_q.size()];
    for (i = 0; i < data_q.size(); i++)
        data_array[i] = data_q[i];
    void'(tr.unpack_bytes(data_array));
    `uvm_info("my_monitor", "end collect one pkt", UVM_LOW)
endtask
