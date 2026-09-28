// 2.3.4：agent，把 sequencer/driver/monitor 封装在一起
// 同一个 agent 通过 is_active 区分 active（含 driver）和 passive（仅 monitor）
class my_agent extends uvm_agent;

    my_sequencer sqr;
    my_driver    drv;
    my_monitor   mon;

    // monitor 的 ap 直接引用给 agent 的 ap，供 env 使用
    uvm_analysis_port #(my_transaction) ap;

    uvm_active_passive_enum is_active;

    `uvm_component_utils(my_agent)

    function new(string name = "my_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    extern virtual function void build_phase(uvm_phase phase);
    extern virtual function void connect_phase(uvm_phase phase);

endclass

function void my_agent::build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(uvm_active_passive_enum)::get(this, "", "is_active", is_active))
        `uvm_fatal("my_agent", "is_active must be set!")
    if (is_active == UVM_ACTIVE) begin
        sqr = my_sequencer::type_id::create("sqr", this);
        drv = my_driver::type_id::create("drv", this);
    end
    mon = my_monitor::type_id::create("mon", this);
endfunction

function void my_agent::connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (is_active == UVM_ACTIVE)
        drv.seq_item_port.connect(sqr.seq_item_export);
    ap = mon.ap;
endfunction
