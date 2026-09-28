# 21. AMBA_Bus 一键仿真脚本（Windows 本机 PowerShell 层，需 iverilog 在 PATH）
# 用法：
#   在 21. AMBA_Bus 目录下打开 PowerShell，执行：
#   .\scripts\run_all.ps1
#   （若执行策略受限：powershell -ExecutionPolicy Bypass -File .\scripts\run_all.ps1）

$ErrorActionPreference = "Stop"

# 脚本所在目录的上一级 = 21. AMBA_Bus 根目录
$root = Split-Path -Parent $PSScriptRoot
Set-Location (Join-Path $root "sim")   # 在 sim 目录下运行，VCD 生成在这里

$tests = @(
    @{ Name = "AHB-Lite slave"; RTL = "..\rtl\ahb_lite_slave.v"; TB = "ahb_lite_slave_tb.v"; Out = "ahb_lite_slave_sim.vvp" },
    @{ Name = "AXI4-Lite slave"; RTL = "..\rtl\axi_lite_slave.v"; TB = "axi_lite_slave_tb.v"; Out = "axi_lite_slave_sim.vvp" }
)

$allPass = $true
foreach ($t in $tests) {
    Write-Host ""
    Write-Host "===== $($t.Name) =====" -ForegroundColor Cyan

    iverilog -g2012 -o $t.Out $t.RTL $t.TB
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[FAIL] $($t.Name): compile error" -ForegroundColor Red
        $allPass = $false
        continue
    }

    $output = vvp $t.Out | Out-String
    Write-Host $output

    if ($output -match "ALL .* PASSED") {
        Write-Host ">>> $($t.Name): PASSED" -ForegroundColor Green
    } else {
        Write-Host ">>> $($t.Name): FAILED" -ForegroundColor Red
        $allPass = $false
    }
}

Write-Host ""
if ($allPass) {
    Write-Host "All AMBA_Bus tests PASSED" -ForegroundColor Green
    exit 0
} else {
    Write-Host "Some AMBA_Bus tests FAILED" -ForegroundColor Red
    exit 1
}
