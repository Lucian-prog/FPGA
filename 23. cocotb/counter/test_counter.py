import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, ReadOnly, RisingEdge, Timer


@cocotb.test(timeout_time=2, timeout_unit="us")
async def counter_basic(dut):
  dut.clk.value = 0
  dut.rst_n.value = 0
  dut.en_i.value = 0
  Clock(dut.clk, 10, unit="ns").start(start_high=False)

  # 上升沿之后等待 RTL 更新完成，再检查复位结果。
  await RisingEdge(dut.clk)
  await ReadOnly()
  assert int(dut.count_o.value) == 0, "复位后没有清零"

  # 在下降沿释放复位，避免和 DUT 的上升沿采样竞争。
  await FallingEdge(dut.clk)
  dut.rst_n.value = 1

  expected = 0
  # 先计数 5 拍，再暂停 3 拍，继续 13 拍跨过 15 -> 0。
  enables = [1] * 5 + [0] * 3 + [1] * 13
  for cycle, enable in enumerate(enables, start=1):
    await FallingEdge(dut.clk)
    dut.en_i.value = enable
    await RisingEdge(dut.clk)
    expected = (expected + enable) % 16
    await ReadOnly()
    actual = int(dut.count_o.value)
    assert actual == expected, (
      f"第 {cycle} 拍: en={enable}, 期望 {expected}, 实际 {actual}"
    )
    dut._log.info("cycle=%02d en=%d expected=%d actual=%d",
                  cycle, enable, expected, actual)

  # 当前计数非零，在两个上升沿之间拉低复位，验证异步清零。
  await FallingEdge(dut.clk)
  dut.rst_n.value = 0
  await Timer(1, unit="ns")
  await ReadOnly()
  assert int(dut.count_o.value) == 0, "异步复位未立即清零"

  # 复位保持有效时，即使 en=1，也必须保持 0。
  await RisingEdge(dut.clk)
  await ReadOnly()
  assert int(dut.count_o.value) == 0, "复位优先级错误"

  await FallingEdge(dut.clk)
  dut.rst_n.value = 1
  await RisingEdge(dut.clk)
  await ReadOnly()
  assert int(dut.count_o.value) == 1, "复位释放后未恢复计数"
