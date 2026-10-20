#Requires -Version 7.0
<#
.SYNOPSIS
  flutter test 的进程外看门狗包装器（本项目所有 flutter test 一律经此脚本运行）。

.DESCRIPTION
  为什么需要它（见 app/test/TESTING.md §2）：
  testWidgets 跑在 AutomatedTestWidgetsFlutterBinding 的 FakeAsync 假时钟区，
  dart:io / isolate / ReceivePort 的回调走真实事件循环，测试体内 await 真实 IO 永不返回；
  而 flutter_test 自己的超时计时器也记在假时钟上 —— 假时间不前进 → 超时永不触发
  → 进程无限挂死，CI/会话被拖死（M1-④ 会话曾两次因此被取消）。
  本脚本在 flutter 进程之外用真实墙钟计时，超时即杀整个进程树并 exit 1。

  行为：
   - Start-Process -PassThru -RedirectStandardOutput/-Error 落日志（不让 GUI/子进程持有本 shell 管道）
   - 每 30s 打印一次心跳（已用时 + 日志最后一行），便于长跑观察
   - 超时：Stop-Process 整个进程树（含 dart / cmd 子进程）+ 孤儿进程清扫 + 打印日志尾部 + exit 1
   - 正常结束：透传 flutter 的 exit code；成功时打印总时长

.PARAMETER TimeoutSec
  墙钟超时秒数，默认 600。看门狗自验证时用 -TimeoutSec 30。

.PARAMETER TestTarget
  传给 flutter test 的路径/文件；留空 = 全仓 test/。

.PARAMETER FlutterArgs
  追加给 flutter test 的原始参数（如 '--name','某用例','--concurrency=1'）。

.EXAMPLE
  pwsh tools/run_tests_safe.ps1
.EXAMPLE
  pwsh tools/run_tests_safe.ps1 -TestTarget test/features_test.dart -TimeoutSec 180
#>
[CmdletBinding()]
param(
  [ValidateRange(5, 86400)]
  [int]$TimeoutSec = 600,

  [string]$AppDir = (Join-Path $PSScriptRoot '..\app'),

  [string[]]$TestTarget = @(),

  [string[]]$FlutterArgs = @(),

  [int]$TailLines = 60,

  [string]$LogDir = '',

  [switch]$NoRetryNativeAssets,

  [switch]$KeepStaleProcesses
)

$ErrorActionPreference = 'Stop'

$AppDir = (Resolve-Path -LiteralPath $AppDir).Path
if (-not (Test-Path -LiteralPath (Join-Path $AppDir 'pubspec.yaml'))) {
  Write-Error "不是 Flutter 工程目录（缺 pubspec.yaml）: $AppDir"
  exit 2
}

if ([string]::IsNullOrWhiteSpace($LogDir)) {
  $LogDir = Join-Path $AppDir 'build\test_logs'
}
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$outLog = Join-Path $LogDir "test-$stamp.out.log"
$errLog = Join-Path $LogDir "test-$stamp.err.log"

$flutterBat = 'C:\flutter\bin\flutter.bat'
if (-not (Test-Path -LiteralPath $flutterBat)) {
  $cmd = Get-Command flutter -ErrorAction SilentlyContinue
  if ($null -eq $cmd) { Write-Error 'flutter 不在 PATH 且 C:\flutter\bin\flutter.bat 不存在'; exit 2 }
  $flutterBat = $cmd.Source
}

$argList = [System.Collections.Generic.List[string]]::new()
$argList.Add('test')
$argList.Add('--reporter')
$argList.Add('expanded')
foreach ($t in $TestTarget) { $argList.Add($t) }
foreach ($a in $FlutterArgs) { $argList.Add($a) }

function Write-Tail {
  param([string]$Path, [int]$Lines)
  if (-not (Test-Path -LiteralPath $Path)) { return }
  $len = (Get-Item -LiteralPath $Path).Length
  if ($len -eq 0) { Write-Host "  <$([System.IO.Path]::GetFileName($Path)) 为空>"; return }
  Write-Host "  ── $([System.IO.Path]::GetFileName($Path)) 尾部 $Lines 行 ──"
  Get-Content -LiteralPath $Path -Tail $Lines | ForEach-Object { Write-Host "  $_" }
}

function Get-LastLogLine {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { return '' }
  $l = Get-Content -LiteralPath $Path -Tail 1 -ErrorAction SilentlyContinue
  if ($null -eq $l) { return '' }
  $l = ($l -join '').Trim()
  if ($l.Length -gt 110) { $l = $l.Substring(0, 110) + '…' }
  return $l
}

# 进程树杀灭：CIM 按 ParentProcessId 做 BFS，只认「本次启动之后创建」的进程（防 PID 复用误杀）。
function Stop-ProcessTree {
  param([int]$RootPid, [datetime]$Since)
  $victims = [System.Collections.Generic.List[int]]::new()
  $victims.Add($RootPid)
  $queue = [System.Collections.Generic.Queue[int]]::new()
  $queue.Enqueue($RootPid)
  try {
    $procs = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
      Select-Object ProcessId, ParentProcessId, CreationDate, Name)
  } catch { $procs = @() }
  while ($queue.Count -gt 0) {
    $cur = $queue.Dequeue()
    foreach ($p in $procs) {
      if ($p.ParentProcessId -ne $cur) { continue }
      if ($victims.Contains([int]$p.ProcessId)) { continue }
      if ($null -ne $p.CreationDate -and $p.CreationDate -lt $Since) { continue }
      $victims.Add([int]$p.ProcessId)
      $queue.Enqueue([int]$p.ProcessId)
    }
  }
  # taskkill /T 兜底（CIM 快照可能漏掉极短命的中间层）
  & taskkill.exe /PID $RootPid /T /F 2>&1 | Out-Null
  foreach ($v in ($victims | Sort-Object -Descending)) {
    try { Stop-Process -Id $v -Force -ErrorAction Stop } catch { }
  }
  return $victims
}

# 孤儿清扫：本次启动后创建、命令行指向本工程、名字为 dart/flutter 的残留进程。
function Stop-Orphans {
  param([datetime]$Since, [string]$WorkDir)
  $killed = [System.Collections.Generic.List[string]]::new()
  try {
    $cands = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
      Where-Object {
        $_.Name -match '^(dart|flutter|booksift)' -and
        $null -ne $_.CreationDate -and $_.CreationDate -ge $Since -and
        ($_.CommandLine -like "*$WorkDir*")
      })
  } catch { $cands = @() }
  foreach ($c in $cands) {
    try {
      Stop-Process -Id $c.ProcessId -Force -ErrorAction Stop
      $killed.Add("$($c.Name)#$($c.ProcessId)")
    } catch { }
  }
  return $killed
}

# 起飞前清扫：上一轮被取消/挂死的 flutter test 会留下 dart.exe 孤儿，
# 它持有已加载的 build\native_assets\windows\sqlite3.dll → 后续每次 flutter test 都以
# PathExistsException(errno 183) 崩溃（本项目已实测两次会话被拖死）。
# 只认命令行同时含 flutter_tools.snapshot + test + 本工程路径的 dart 进程，不误伤分析服务器。
function Stop-StaleTestRuns {
  param([string]$WorkDir)
  $killed = [System.Collections.Generic.List[string]]::new()
  try {
    $cands = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
      Where-Object {
        $_.Name -eq 'dart.exe' -and
        ($_.CommandLine -like '*flutter_tools.snapshot*') -and
        ($_.CommandLine -like '*test*') -and
        ($_.CommandLine -like "*$WorkDir*")
      })
  } catch { $cands = @() }
  foreach ($c in $cands) {
    $tree = Stop-ProcessTree -RootPid $c.ProcessId -Since ([datetime]::MinValue)
    $killed.Add("dart#$($c.ProcessId)(树 $($tree.Count))")
  }
  return $killed
}

# 释放 native_assets 锁（删不掉 = 仍被占用 → 报出占用者，不静默）。
function Clear-NativeAssets {
  param([string]$WorkDir)
  $na = Join-Path $WorkDir 'build\native_assets'
  if (-not (Test-Path -LiteralPath $na)) { return $true }
  Remove-Item -LiteralPath $na -Recurse -Force -ErrorAction SilentlyContinue
  if (Test-Path -LiteralPath $na) {
    Write-Host "[watchdog] ! 无法删除 $na（被进程占用），先清孤儿再重试" -ForegroundColor Yellow
    return $false
  }
  return $true
}

function Invoke-FlutterTest {
  $started = Get-Date
  $proc = Start-Process -FilePath $flutterBat `
    -ArgumentList $argList `
    -WorkingDirectory $AppDir `
    -NoNewWindow -PassThru `
    -RedirectStandardOutput $outLog `
    -RedirectStandardError $errLog

  Write-Host "[watchdog] flutter test 启动 PID=$($proc.Id) 墙钟上限=${TimeoutSec}s"
  Write-Host "[watchdog] 工作目录 $AppDir"
  Write-Host "[watchdog] 日志 $outLog"

  $heartbeat = 30
  $elapsed = 0
  $exited = $false
  while (-not $exited) {
    $slice = [Math]::Min($heartbeat, [Math]::Max(1, $TimeoutSec - $elapsed))
    $exited = $proc.WaitForExit($slice * 1000)
    $elapsed = [int]((Get-Date) - $started).TotalSeconds
    if (-not $exited) {
      if ($elapsed -ge $TimeoutSec) { break }
      Write-Host "[watchdog] …${elapsed}s / ${TimeoutSec}s  $(Get-LastLogLine $outLog)"
    }
  }

  if (-not $proc.HasExited) {
    $victims = Stop-ProcessTree -RootPid $proc.Id -Since $started.AddSeconds(-2)
    Start-Sleep -Milliseconds 600
    $orphans = Stop-Orphans -Since $started.AddSeconds(-2) -WorkDir $AppDir
    Write-Host ''
    Write-Host "[watchdog] ✗ 超时 ${TimeoutSec}s：已杀进程树 $($victims -join ',')" -ForegroundColor Red
    if ($orphans.Count -gt 0) { Write-Host "[watchdog] 孤儿清扫: $($orphans -join ',')" -ForegroundColor Red }
    Write-Host "[watchdog] 日志尾部（挂死点即最后一条用例）:" -ForegroundColor Yellow
    Write-Tail -Path $outLog -Lines $TailLines
    Write-Tail -Path $errLog -Lines 20
    Write-Host ''
    Write-Host "[watchdog] 判读：最后一条用例即假时钟区挂死点，按 app/test/TESTING.md §3 改造。" -ForegroundColor Yellow
    return @{ Code = 1; TimedOut = $true; Seconds = $elapsed }
  }

  $code = $proc.ExitCode
  return @{ Code = $code; TimedOut = $false; Seconds = [int]((Get-Date) - $started).TotalSeconds }
}

if (-not $KeepStaleProcesses) {
  $stale = Stop-StaleTestRuns -WorkDir $AppDir
  if ($stale.Count -gt 0) {
    Write-Host "[watchdog] 起飞前清扫挂死的 flutter test 孤儿进程: $($stale -join ', ')" -ForegroundColor Yellow
    Start-Sleep -Milliseconds 800
    $null = Clear-NativeAssets -WorkDir $AppDir
  }
}

$sw = [System.Diagnostics.Stopwatch]::StartNew()
$res = Invoke-FlutterTest

# 已知 Windows 侧 native-assets 竞态：build\native_assets\windows\sqlite3.dll 已存在 → 拷贝失败。
# 与测试代码无关，清掉 native_assets 后重跑一次。
if ($res.Code -ne 0 -and -not $res.TimedOut -and -not $NoRetryNativeAssets) {
  $hits = Select-String -LiteralPath $outLog -Pattern 'PathExistsException' -SimpleMatch -ErrorAction SilentlyContinue
  if ($hits) {
    Write-Host '[watchdog] 命中 native_assets sqlite3.dll 拷贝竞态，清孤儿+清理后重跑一次…' -ForegroundColor Yellow
    $stale = Stop-StaleTestRuns -WorkDir $AppDir
    if ($stale.Count -gt 0) { Write-Host "[watchdog] 占用者: $($stale -join ', ')" -ForegroundColor Yellow }
    Start-Sleep -Milliseconds 800
    if (-not (Clear-NativeAssets -WorkDir $AppDir)) { exit 3 }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $outLog = Join-Path $LogDir "test-$stamp.out.log"
    $errLog = Join-Path $LogDir "test-$stamp.err.log"
    $res = Invoke-FlutterTest
  }
}
$sw.Stop()

Write-Host ''
if ($res.TimedOut) {
  Write-Host "[watchdog] 结果：TIMEOUT（墙钟 ${TimeoutSec}s）  总耗时 $([int]$sw.Elapsed.TotalSeconds)s" -ForegroundColor Red
  exit 1
}
if ($res.Code -eq 0) {
  Write-Host "[watchdog] ✓ 全绿  flutter 用时 $($res.Seconds)s  脚本总耗时 $([int]$sw.Elapsed.TotalSeconds)s  exit=0" -ForegroundColor Green
  Write-Host "[watchdog] 日志 $outLog"
  Get-Content -LiteralPath $outLog -Tail 3 | ForEach-Object { Write-Host "  $_" }
} else {
  Write-Host "[watchdog] ✗ 失败 exit=$($res.Code)  用时 $($res.Seconds)s" -ForegroundColor Red
  Write-Tail -Path $outLog -Lines $TailLines
  Write-Tail -Path $errLog -Lines 20
}
exit $res.Code
