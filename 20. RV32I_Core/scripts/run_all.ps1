$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$buildDir = Join-Path ([System.IO.Path]::GetTempPath()) "rv32i_core_sim"

if (Test-Path -LiteralPath $buildDir) {
  Remove-Item -LiteralPath $buildDir -Recurse -Force
}
New-Item -ItemType Directory -Path $buildDir | Out-Null

$tests = @(
  @{
    Name = "alu"
    Top = "rv32_alu_tb"
    Sources = @("sim/rv32_alu_tb.sv")
  },
  @{
    Name = "imm_ext"
    Top = "rv32_imm_ext_tb"
    Sources = @("sim/rv32_imm_ext_tb.sv")
  },
  @{
    Name = "regfile"
    Top = "rv32_regfile_tb"
    Sources = @("sim/rv32_regfile_tb.sv")
  },
  @{
    Name = "decoder"
    Top = "rv32_decoder_tb"
    Sources = @("sim/rv32_decoder_tb.sv")
  },
  @{
    Name = "core"
    Top = "rv32_core_tb"
    Sources = @(
      "sim/rv32_imem_model.sv",
      "sim/rv32_dmem_model.sv",
      "sim/rv32_system_top.sv",
      "sim/rv32_core_tb.sv"
    )
  }
)

Push-Location $projectRoot
try {
  foreach ($test in $tests) {
    $output = Join-Path $buildDir "$($test.Name).vvp"
    $arguments = @(
      "-g2012",
      "-Wall",
      "-Wno-timescale",
      "-s", $test.Top,
      "-o", $output,
      "-c", "filelist.f"
    ) + $test.Sources

    Write-Host "Compiling $($test.Name)..."
    & iverilog @arguments
    if ($LASTEXITCODE -ne 0) {
      throw "Compilation failed: $($test.Name)"
    }

    Write-Host "Running $($test.Name)..."
    & vvp $output
    if ($LASTEXITCODE -ne 0) {
      throw "Simulation failed: $($test.Name)"
    }
  }

  Write-Host "All RV32 teaching-core tests passed."
} finally {
  Pop-Location
}
