// 代码清单 2-12：interface，连接验证平台与 DUT
// driver 等类中只能使用 virtual my_if，不能直接声明 my_if
interface my_if(input clk, input rst_n);

    logic [7:0] data;
    logic       valid;

endinterface
