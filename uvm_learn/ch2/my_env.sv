// 2.3.2：env，把所有组件包在一起并完成 TLM 连接
class my_env extends uvm_env;

    my_agent      i_agt;   // 输入侧，active：驱动 DUT 并监测输入
    my_agent      o_agt;   // 输出侧，passive：仅监测 DUT 输出
    my_model      mdl;
    my_scoreboard scb;

    // analysis_port 与 blocking_get_port 之间的中转 fifo
    uvm_tlm_analysis_fifo #(my_transaction) agt_mdl_fifo;

    `uvm_component_utils(my_env)

    function new(string name = "my_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    extern virtual function void build_phase(uvm_phase phase);
    extern virtual function void connect_phase(uvm_phase phase);

endclass

function void my_env::build_phase(uvm_phase phase);
    super.build_phase(phase);
    i_agt = my_agent::type_id::create("i_agt", this);
    o_agt = my_agent::type_id::create("o_agt", this);
    mdl   = my_model::type_id::create("mdl", this);
    scb   = my_scoreboard::type_id::create("scb", this);

    uvm_config_db#(uvm_active_passive_enum)::set(this, "i_agt", "is_active", UVM_ACTIVE);
    uvm_config_db#(uvm_active_passive_enum)::set(this, "o_agt", "is_active", UVM_PASSIVE);

    agt_mdl_fifo = new("agt_mdl_fifo", this);
endfunction

function void my_env::connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    // 输入侧 monitor -> model
    i_agt.ap.connect(agt_mdl_fifo.analysis_export);
    mdl.port.connect(agt_mdl_fifo.blocking_get_export);
    // model -> scoreboard（期望值）
    mdl.ap.connect(scb.model_imp);
    // 输出侧 monitor -> scoreboard（实际值）
    o_agt.ap.connect(scb.monitor_imp);
endfunction
