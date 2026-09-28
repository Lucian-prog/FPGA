// 2.2.2 / 2.4：driver，把 transaction 拆成字节流驱动 DUT
class my_driver extends uvm_driver #(my_transaction);

    virtual my_if vif;

    `uvm_component_utils(my_driver)

    function new(string name = "my_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    extern virtual function void build_phase(uvm_phase phase);
    extern virtual task main_phase(uvm_phase phase);
    extern task drive_one_pkt(my_transaction tr);

endclass

function void my_driver::build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual my_if)::get(this, "", "vif", vif))
        `uvm_fatal("my_driver", "virtual interface must be set for vif!!!")
endfunction

task my_driver::main_phase(uvm_phase phase);
    vif.data  <= 8'b0;
    vif.valid <= 1'b0;
    while (!vif.rst_n)
        @(posedge vif.clk);
    // objection 由 sequence 控制；driver 只负责从 sequencer 拿 transaction 并驱动
    while (1) begin
        seq_item_port.get_next_item(req);
        drive_one_pkt(req);
        seq_item_port.item_done();
    end
endtask

task my_driver::drive_one_pkt(my_transaction tr);
    byte unsigned data_q[];
    int data_size;
    int i;

    // field automation 的 pack：把 transaction 打成字节流
    data_size = tr.pack_bytes(data_q) / 8;
    `uvm_info("my_driver", "begin to drive one pkt", UVM_LOW)
    repeat (3) @(posedge vif.clk);
    for (i = 0; i < data_size; i++) begin
        @(posedge vif.clk);
        vif.data  <= data_q[i];
        vif.valid <= 1'b1;
    end
    @(posedge vif.clk);
    vif.valid <= 1'b0;
    vif.data  <= 8'b0;
    `uvm_info("my_driver", "end drive one pkt", UVM_LOW)
endtask
