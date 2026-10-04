# Windows PowerShell: .\sim\run_audio_process.ps1
# 使用 Icarus；生成物全部写到系统临时目录。
$ErrorActionPreference = 'Stop'
$projectDir = Split-Path -Parent $PSScriptRoot
$buildDir = Join-Path ([IO.Path]::GetTempPath()) ('audio_process_' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $buildDir | Out-Null
$algorithmFiles = @(
  (Join-Path $projectDir 'src/AUDIO_PROCESS_LITE.v'),
  (Join-Path $projectDir 'src/iir.v'),
  (Join-Path $projectDir 'src/agc.v')
)

$algorithmSim = Join-Path $buildDir 'audio_process.vvp'
& iverilog -g2012 -s audio_process_tb -o $algorithmSim @algorithmFiles `
  (Join-Path $PSScriptRoot 'audio_process_tb.sv') `
  (Join-Path $PSScriptRoot 'audio_process_reference.v') `
  (Join-Path $projectDir 'src/iir_ch.v')
if ($LASTEXITCODE -ne 0) { throw 'Algorithm test compilation failed' }
& vvp $algorithmSim
if ($LASTEXITCODE -ne 0) { throw 'Algorithm test failed' }

$receiveSim = Join-Path $buildDir 'i2s_receive.vvp'
& iverilog -g2012 -s i2s_receive_tb -o $receiveSim @algorithmFiles `
  (Join-Path $PSScriptRoot 'i2s_receive_tb.sv') `
  (Join-Path $projectDir 'src/clkdiv.v') `
  (Join-Path $projectDir 'src/i2s_receive.v') `
  (Join-Path $projectDir 'src/mic_serial.v')
if ($LASTEXITCODE -ne 0) { throw 'I2S integration test compilation failed' }
& vvp $receiveSim
if ($LASTEXITCODE -ne 0) { throw 'I2S zero-padding test failed' }
& vvp $receiveSim +PAD_Z
if ($LASTEXITCODE -ne 0) { throw 'I2S high-impedance padding test failed' }
Write-Output "PASS: all audio tests; build artifacts: $buildDir"
