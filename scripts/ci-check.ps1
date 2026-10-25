# 黄河记忆 · 本地 CI 门禁（M11）
#
# 用途：在提交/交付前一次性执行「项目规则检查 → clean 构建 → 本地单元测试 → 告警基线比对」，
# 任一步失败即以非 0 退出码结束，可被本地脚本或 CI Runner 直接调用。
#
# 用法（工程根目录）：
#   powershell -ExecutionPolicy Bypass -File .\scripts\ci-check.ps1
#   powershell -ExecutionPolicy Bypass -File .\scripts\ci-check.ps1 -SkipClean
#
# 环境：默认使用 DevEco Studio 本地安装路径；如安装在别处，先设置
#   $env:DEVECO_SDK_HOME = '<DevEco Studio 安装目录>\sdk'
# 脚本会从 SDK 路径推导 DevEco 根目录、内置 Node 与 JBR。

param(
  [switch]$SkipClean
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

# ==================== 环境准备 ====================
$sdkHome = $env:DEVECO_SDK_HOME
if (-not $sdkHome) {
  $sdkHome = 'E:\DevEco Studio\sdk'
}
if (-not (Test-Path $sdkHome)) {
  Write-Error "找不到 SDK：$sdkHome（请设置 DEVECO_SDK_HOME）"
  exit 1
}
$devecoHome = Split-Path -Parent $sdkHome
$hvigor = Join-Path $devecoHome 'tools\hvigor\bin\hvigorw.bat'
if (-not (Test-Path $hvigor)) {
  Write-Error "找不到 hvigorw：$hvigor"
  exit 1
}

$env:DEVECO_SDK_HOME = $sdkHome
$javaHome = Join-Path $devecoHome 'jbr'
if (Test-Path $javaHome) {
  $env:JAVA_HOME = $javaHome
  $env:Path = (Join-Path $javaHome 'bin') + ';' + $env:Path
}
$nodeHome = Join-Path $devecoHome 'tools\node'
if (Test-Path $nodeHome) {
  $env:NODE_HOME = $nodeHome
}

$logDir = Join-Path $root '.hvigor'
if (-not (Test-Path $logDir)) {
  New-Item -ItemType Directory -Path $logDir | Out-Null
}

function Invoke-Hvigor {
  param([string]$HvigorArguments, [string]$LogFile)
  Write-Host "> hvigorw $HvigorArguments"
  # hvigor 把 WARN 写到 stderr；PowerShell 5 在 EAP=Stop 下会把原生 stderr 当成终止错误，
  # 这里临时降级为 Continue，靠退出码判断成败（日志仍完整保留）。
  $previousEap = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    & $hvigor ($HvigorArguments.Split(' ')) 2>&1 | Tee-Object -FilePath $LogFile
  } finally {
    $ErrorActionPreference = $previousEap
  }
  if ($LASTEXITCODE -ne 0) {
    Write-Error "hvigor 执行失败：$HvigorArguments（日志 $LogFile）"
    exit 1
  }
}

# ==================== 1. 项目规则检查（禁 any / 禁解构） ====================
Write-Host '== 1/4 项目规则检查 =='
$sources = Get-ChildItem -Path (Join-Path $root 'entry\src\main\ets') -Recurse -Filter '*.ets'
$violations = @()
foreach ($file in $sources) {
  $lines = Get-Content $file.FullName
  for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    if ($line -match ':\s*any\b' -or $line -match 'as\s+any\b') {
      $violations += "$($file.FullName):$($i + 1) 使用 any"
    }
    if ($line -match '^\s*(const|let|var)\s*\{') {
      $violations += "$($file.FullName):$($i + 1) 使用解构声明"
    }
  }
}
if ($violations.Count -gt 0) {
  $violations | ForEach-Object { Write-Host "  $_" }
  Write-Error "项目规则检查未通过（$($violations.Count) 处）"
  exit 1
}
Write-Host "  通过：$($sources.Count) 个 ETS 文件无 any / 解构"

# ==================== 2. 构建 ====================
Write-Host '== 2/4 构建 =='
if (-not $SkipClean) {
  Invoke-Hvigor 'clean --no-daemon' (Join-Path $logDir 'ci-clean.log')
}
$buildLog = Join-Path $logDir 'ci-build.log'
Invoke-Hvigor 'assembleHap --mode module -p product=default -p buildMode=debug --no-daemon' $buildLog

# 告警基线（O3）：L6 路由集中后为 4 条，按「文件 + 类型」比对；此处只做数量上限门禁，行号漂移不阻塞
$raw = Get-Content $buildLog -Raw
$clean = $raw -replace "$([char]27)\[[0-9;]*m", ''
$warnCount = ([regex]::Matches($clean, 'ArkTS:WARN File:')).Count
if ($warnCount -gt 4) {
  Write-Error "构建告警超出基线：$warnCount > 4（日志 $buildLog）"
  exit 1
}
Write-Host "  通过：BUILD SUCCESSFUL，ArkTS WARN $warnCount 条（基线上限 4）"

# ==================== 3. 本地单元测试 ====================
Write-Host '== 3/4 本地单元测试 =='
$testResult = Join-Path $root 'entry\.test\default\intermediates\test\coverage_data\test_result.txt'
if (Test-Path $testResult) {
  Remove-Item $testResult -Force
}
Invoke-Hvigor 'test -p module=entry -p coverage=false --no-daemon' (Join-Path $logDir 'ci-test.log')
if (-not (Test-Path $testResult)) {
  Write-Error "未生成测试结果文件：$testResult"
  exit 1
}
$summary = Select-String -Path $testResult -Pattern 'Tests run: (\d+), Failure: (\d+), Error: (\d+), Pass: (\d+), Ignore: (\d+)'
if ($null -eq $summary -or $summary.Matches.Count -eq 0) {
  Write-Error "无法解析测试结果：$testResult"
  exit 1
}
$m = $summary.Matches[$summary.Matches.Count - 1]
$failure = [int]$m.Groups[2].Value
$errorCount = [int]$m.Groups[3].Value
if ($failure -gt 0 -or $errorCount -gt 0) {
  Write-Error "单元测试失败：Failure=$failure Error=$errorCount（明细 $testResult）"
  exit 1
}
Write-Host "  通过：$($m.Groups[1].Value) 个用例全部成功"

# ==================== 4. 结果 ====================
Write-Host '== 4/4 门禁通过 =='
Write-Host '  build + unit test + 规则检查 均通过，可提交/交付'
exit 0
