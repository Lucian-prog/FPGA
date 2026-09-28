from pathlib import Path
import sys

from cocotb_tools.runner import get_runner


if __name__ == "__main__":
  project = Path(__file__).resolve().parent
  build = project / "sim_build" / sys.platform
  runner = get_runner("icarus")
  # 仿真顶层直接指定 DUT，不需要额外的 Verilog TB。
  runner.build(
    sources=[project / "counter.v"],
    hdl_toplevel="counter",
    build_dir=build,
    always=True,
    waves=True,
  )
  runner.test(
    hdl_toplevel="counter",
    test_module="test_counter",
    test_dir=project,
    results_xml=build / "results.xml",
    waves=True,
  )
