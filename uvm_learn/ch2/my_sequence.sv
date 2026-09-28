// 2.4.2：sequence，产生随机激励
class my_sequence extends uvm_sequence #(my_transaction);

    my_transaction m_trans;

    `uvm_object_utils(my_sequence)

    function new(string name = "my_sequence");
        super.new(name);
        // UVM 1.1d 书上写法：body 里手动 starting_phase.raise/drop_objection
        // UVM 1.2 中 default_sequence 不再设置 starting_phase，需用自动 objection
        set_automatic_phase_objection(1);
    endfunction

    virtual task body();
        repeat (10) begin
            `uvm_do(m_trans)
        end
        #100;
    endtask

endclass
