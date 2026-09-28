# UVM 学习平台通用 Makefile（Rocky VM + VCS）
TESTNAME ?= my_case0
UVM_VERBOSITY ?= UVM_LOW

COMPILE = vcs -full64 -sverilog -ntb_opts uvm-1.2 -timescale=1ns/1ns

all: comp run

comp:
	$(COMPILE) top_tb.sv dut.sv -l comp.log

run:
	./simv +UVM_TESTNAME=$(TESTNAME) +UVM_VERBOSITY=$(UVM_VERBOSITY) -l sim.log

clean:
	rm -rf simv simv.daidir csrc ucli.key vc_hdrs.h *.log *.vpd *.fsdb DVEfiles
