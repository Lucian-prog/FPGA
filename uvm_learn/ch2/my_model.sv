// 2.3.5：reference model，产生期望结果
// 第 2 章的模型只做「复制并打印」，模拟真实平台中的参考计算
class my_model extends uvm_component;

    // blocking_get_port 不能直接连 analysis_port，env 中用 uvm_tlm_analysis_fifo 中转
    uvm_blocking_get_port #(my_transaction) port;
    uvm_analysis_port #(my_transaction) ap;

    `uvm_component_utils(my_model)

    function new(string name = "my_model", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    extern virtual function void build_phase(uvm_phase phase);
    extern virtual task main_phase(uvm_phase phase);

endclass

function void my_model::build_phase(uvm_phase phase);
    super.build_phase(phase);
    port = new("port", this);
    ap   = new("ap", this);
endfunction

task my_model::main_phase(uvm_phase phase);
    my_transaction tr;
    my_transaction new_tr;
    super.main_phase(phase);
    while (1) begin
        port.get(tr);
        new_tr = new("new_tr");
        new_tr.copy(tr);
        `uvm_info("my_model", "get one transaction, copy and print it:", UVM_LOW)
        new_tr.print();
        ap.write(new_tr);
    end
endtask
