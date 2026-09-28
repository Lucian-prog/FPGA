// 2.3.1：transaction，模拟一个以太网帧
class my_transaction extends uvm_sequence_item;

    rand bit [47:0]     dmac;        // 目的 MAC
    rand bit [47:0]     smac;        // 源 MAC
    rand bit [15:0]     ether_type;  // 帧类型
    rand byte unsigned  pload[];     // 载荷
    rand bit [31:0]     crc;         // CRC 校验

    constraint pload_cons {
        pload.size() >= 46;
        pload.size() <= 1500;
    }

    // field automation：自动生成 copy/compare/pack/unpack/print
    `uvm_object_utils_begin(my_transaction)
        `uvm_field_int(dmac,        UVM_ALL_ON)
        `uvm_field_int(smac,        UVM_ALL_ON)
        `uvm_field_int(ether_type,  UVM_ALL_ON)
        `uvm_field_array_int(pload, UVM_ALL_ON)
        `uvm_field_int(crc,         UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "my_transaction");
        super.new(name);
    endfunction

endclass
