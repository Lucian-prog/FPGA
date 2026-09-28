# 2.2 复现平台（driver-only）Makefile
COMPILE = vcs -full64 -sverilog -ntb_opts uvm-1.2 -timescale=1ns/1ns

all: comp run

comp:
	$(COMPILE) top_tb.sv dut.sv -l comp.log

run:
	./simv -l sim.log

clean:
	rm -rf simv simv.daidir csrc ucli.key vc_hdrs.h *.log
