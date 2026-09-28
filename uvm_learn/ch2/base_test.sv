// 2.5.1：base_test 与测试用例
// base_test 负责 env 的创建和结果汇报；具体 case 继承它并通过 config_db 差异化
class base_test extends uvm_test;

    my_env env;

    `uvm_component_utils(base_test)

    function new(string name = "base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    extern virtual function void build_phase(uvm_phase phase);
    extern virtual task main_phase(uvm_phase phase);
    extern virtual function void report_phase(uvm_phase phase);

endclass

function void base_test::build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = my_env::type_id::create("env", this);
endfunction

// 5.2.4：drain time —— sequence 的 objection 撤销后，最后一笔数据
// 还要穿过 DUT -> o_agt -> scoreboard，phase 需多等一段时间再结束
task base_test::main_phase(uvm_phase phase);
    phase.phase_done.set_drain_time(this, 1us);
endtask

// report_phase 中统计 UVM_ERROR 数量，给出用例通过与否的结论
function void base_test::report_phase(uvm_phase phase);
    uvm_report_server server;
    int err_num;
    super.report_phase(phase);

    server = uvm_report_server::get_server();
    err_num = server.get_severity_count(UVM_ERROR);
    if (err_num != 0)
        $display("TEST FAILED, error number = %0d", err_num);
    else
        $display("TEST PASSED!!!");
endfunction

class my_case0 extends base_test;

    `uvm_component_utils(my_case0)

    function new(string name = "my_case0", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // 2.4.3：用 default_sequence 的方式启动 sequence
        uvm_config_db#(uvm_object_wrapper)::set(this,
                                                "env.i_agt.sqr.main_phase",
                                                "default_sequence",
                                                my_sequence::type_id::get());
    endfunction

endclass
