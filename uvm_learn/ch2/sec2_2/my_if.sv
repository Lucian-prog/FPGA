// my_if.sv —— 2.2.1 引入
// interface：把一组相关信号打包成"一根线缆"，driver 以后都从它上面取信号。
// 注意它是静态的硬件对象，实例化发生在 module 世界里（见 top_tb.sv）。
interface my_if(input logic clk, input logic rst_n);

    logic [7:0] data;    // 数据字节
    logic       valid;   // data 有效指示

endinterface
