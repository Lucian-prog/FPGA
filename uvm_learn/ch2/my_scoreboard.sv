// 2.3.6：scoreboard，期望值与实际值比较
// 一个 component 要同时接收两路数据时，用 uvm_analysis_imp_decl 生成两个后缀不同的 imp
`uvm_analysis_imp_decl(_monitor)
`uvm_analysis_imp_decl(_model)

class my_scoreboard extends uvm_scoreboard;

    my_transaction expect_queue[$];

    // model 输出 -> 期望值；o_agt 输出 -> 实际值
    uvm_analysis_imp_model   #(my_transaction, my_scoreboard) model_imp;
    uvm_analysis_imp_monitor #(my_transaction, my_scoreboard) monitor_imp;

    `uvm_component_utils(my_scoreboard)

    function new(string name = "my_scoreboard", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    extern virtual function void build_phase(uvm_phase phase);
    extern function void write_model(my_transaction tr);
    extern function void write_monitor(my_transaction tr);

endclass

function void my_scoreboard::build_phase(uvm_phase phase);
    super.build_phase(phase);
    model_imp   = new("model_imp",   this);
    monitor_imp = new("monitor_imp", this);
endfunction

function void my_scoreboard::write_model(my_transaction tr);
    expect_queue.push_back(tr);
endfunction

function void my_scoreboard::write_monitor(my_transaction tr);
    my_transaction tmp;
    if (expect_queue.size() > 0) begin
        tmp = expect_queue.pop_front();
        if (tmp.compare(tr))
            `uvm_info("my_scoreboard", "Transaction is OK!", UVM_LOW)
        else
            `uvm_error("my_scoreboard", "Transaction is not OK!")
    end
    else begin
        `uvm_error("my_scoreboard", "Received from DUT, while expect queue is empty")
    end
endfunction
