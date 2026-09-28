// 2.4.1：sequencer，transaction 的搬运工，参数化类型
class my_sequencer extends uvm_sequencer #(my_transaction);

    `uvm_component_utils(my_sequencer)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

endclass
