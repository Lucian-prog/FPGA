module rv32_top (
    input logic clk,
    input logic rst_n,
    input logic [31:0] instr_rdata_i,
    output logic [31:0] instr_addr_o
);  
    logic  [31:0] pc_q;
    logic  [31:0] pc_d;
    logic  [31:0] instr;
    rv32_pc pc_inst (
        .clk(clk),
        .rst_n(rst_n),
        .pc_next_i(pc_d),
        .pc_o(pc_q)
    );

    assign instr = instr_rdata_i;
    assign instr_addr_o = pc_q;



endmodule