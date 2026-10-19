#Requires -Version 7.0
<#
.SYNOPSIS
  构建 headless CLI 并验证发布 bundle 的关键 JSON / 只读 / 网络闸门契约。

.PARAMETER BuildTimeoutSec
  `dart build cli` 墙钟上限，默认 600 秒。
#>
[CmdletBinding()]
param(
  [ValidateRange(60, 1800)]
  [int]$BuildTimeoutSec = 600
)

$ErrorActionPreference = 'Stop'
$RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$AppDir = Join-Path $RepoRoot 'app'
$FlutterDart = 'C:\flutter\bin\cache\dart-sdk\bin\dart.exe'
$LogDir = Join-Path $RepoRoot 'work\verification\cli'
$CliExe = Join-Path $AppDir 'build\cli\windows_x64\bundle\bin\booksift.exe'
$Fixture = Join-Path $AppDir 'test\fixtures\dev_seed.db'

if (-not (Test-Path -LiteralPath $FlutterDart)) {
  throw "Dart SDK not found: $FlutterDart"
}
if (-not (Test-Path -LiteralPath $Fixture)) {
  throw "CLI smoke fixture not found: $Fixture"
}
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

function Invoke-WatchedProcess {
  param(
    [Parameter(Mandatory)][string]$FilePath,
    [Parameter(Mandatory)][string[]]$ArgumentList,
    [Parameter(Mandatory)][string]$WorkingDirectory,
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][int]$TimeoutSec,
    [switch]$ClearNetworkGate
  )

  $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
  $outPath = Join-Path $LogDir "$Name-$stamp.out.log"
  $errPath = Join-Path $LogDir "$Name-$stamp.err.log"
  $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
  $startInfo.FileName = $FilePath
  $startInfo.WorkingDirectory = $WorkingDirectory
  $startInfo.UseShellExecute = $false
  $startInfo.RedirectStandardOutput = $true
  $startInfo.RedirectStandardError = $true
  foreach ($argument in $ArgumentList) { $startInfo.ArgumentList.Add($argument) }
  if ($ClearNetworkGate) { $startInfo.Environment.Remove('BOOKSIFT_NET') }

  $process = [System.Diagnostics.Process]::new()
  $process.StartInfo = $startInfo
  if (-not $process.Start()) { throw "Unable to start $Name" }
  $stdoutTask = $process.StandardOutput.ReadToEndAsync()
  $stderrTask = $process.StandardError.ReadToEndAsync()
  if (-not $process.WaitForExit($TimeoutSec * 1000)) {
    $process.Kill($true)
    $process.WaitForExit()
    [System.IO.File]::WriteAllText($outPath, $stdoutTask.GetAwaiter().GetResult())
    [System.IO.File]::WriteAllText($errPath, $stderrTask.GetAwaiter().GetResult())
    throw "$Name timed out after ${TimeoutSec}s"
  }
  $process.WaitForExit()
  $stdout = $stdoutTask.GetAwaiter().GetResult()
  $stderr = $stderrTask.GetAwaiter().GetResult()
  [System.IO.File]::WriteAllText($outPath, $stdout)
  [System.IO.File]::WriteAllText($errPath, $stderr)
  return [pscustomobject]@{
    Name = $Name
    ExitCode = $process.ExitCode
    Stdout = $stdout
    Stderr = $stderr
  }
}

$build = Invoke-WatchedProcess `
  -FilePath $FlutterDart `
  -ArgumentList @('build', 'cli') `
  -WorkingDirectory $AppDir `
  -Name 'cli-build' `
  -TimeoutSec $BuildTimeoutSec
if ($build.ExitCode -ne 0) {
  throw "dart build cli failed ($($build.ExitCode)); see work/verification/cli/"
}
if (-not (Test-Path -LiteralPath $CliExe)) { throw "CLI executable not found: $CliExe" }

$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "booksift-cli-smoke-$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $tempDir | Out-Null
$dbPath = Join-Path $tempDir 'dev_seed.db'
Copy-Item -LiteralPath $Fixture -Destination $dbPath
$hashBefore = (Get-FileHash -LiteralPath $dbPath -Algorithm SHA256).Hash
try {
  $version = Invoke-WatchedProcess -FilePath $CliExe -ArgumentList @('--json', '--version') `
    -WorkingDirectory $AppDir -Name 'version' -TimeoutSec 30
  if ($version.ExitCode -ne 0) { throw 'CLI version query failed' }
  $versionJson = $version.Stdout | ConvertFrom-Json
  if ($versionJson.name -ne 'booksift' -or [string]::IsNullOrWhiteSpace($versionJson.version)) {
    throw 'CLI version JSON contract failed'
  }

  $classify = Invoke-WatchedProcess -FilePath $CliExe -ArgumentList @(
    '--json', '--no-log-file', 'classify', '--title', '《测试书》推荐', '--floor', '值得一看'
  ) -WorkingDirectory $AppDir -Name 'classify' -TimeoutSec 30
  $classifyJson = $classify.Stdout | ConvertFrom-Json
  if ($classify.ExitCode -ne 0 -or $null -eq $classifyJson.kind) {
    throw 'CLI classification JSON contract failed'
  }

  $globalDbArgs = @('--json', '--no-log-file', '--db', $dbPath)
  $doctor = Invoke-WatchedProcess -FilePath $CliExe -ArgumentList @(
    $globalDbArgs + @('--dict', 'assets/dict/book_dict.txt', 'doctor', '--seed-dir', 'assets/seed')
  ) -WorkingDirectory $AppDir -Name 'doctor' -TimeoutSec 60
  if ($doctor.ExitCode -ne 0 -or $null -eq ($doctor.Stdout | ConvertFrom-Json).checks) {
    throw 'CLI doctor JSON contract failed'
  }

  $plan = Invoke-WatchedProcess -FilePath $CliExe -ArgumentList @($globalDbArgs + @('collect')) `
    -WorkingDirectory $AppDir -Name 'collect-plan' -TimeoutSec 60
  $planJson = $plan.Stdout | ConvertFrom-Json
  if ($plan.ExitCode -ne 0 -or $null -eq $planJson.forums -or $null -eq $planJson.budget) {
    throw 'CLI collect plan JSON contract failed'
  }

  $hot = Invoke-WatchedProcess -FilePath $CliExe -ArgumentList @($globalDbArgs + @('hot', '--limit', '1')) `
    -WorkingDirectory $AppDir -Name 'hot' -TimeoutSec 60
  $hotJson = $hot.Stdout | ConvertFrom-Json
  if ($hot.ExitCode -ne 0 -or @($hotJson.items).Count -eq 0) {
    throw 'CLI hot query did not return fixture data'
  }
  $query = Invoke-WatchedProcess -FilePath $CliExe -ArgumentList @(
    $globalDbArgs + @('query', [string]$hotJson.items[0].name, '--limit', '1')
  ) -WorkingDirectory $AppDir -Name 'query' -TimeoutSec 60
  $queryJson = $query.Stdout | ConvertFrom-Json
  if ($query.ExitCode -ne 0 -or $queryJson.total -lt 1) {
    throw 'CLI query JSON contract failed'
  }

  $facets = Invoke-WatchedProcess -FilePath $CliExe -ArgumentList @(
    $globalDbArgs + @('facets', '--year', '2026', '--month', '10')
  ) -WorkingDirectory $AppDir -Name 'facets' -TimeoutSec 60
  $facetsJson = $facets.Stdout | ConvertFrom-Json
  if ($facets.ExitCode -ne 0 -or $null -eq $facetsJson.dimensions.categories) {
    throw 'CLI facets JSON contract failed'
  }

  $showBook = Invoke-WatchedProcess -FilePath $CliExe -ArgumentList @(
    $globalDbArgs + @('show', 'book', '1')
  ) -WorkingDirectory $AppDir -Name 'show-book' -TimeoutSec 60
  $showBookJson = $showBook.Stdout | ConvertFrom-Json
  if ($showBook.ExitCode -ne 0 -or $showBookJson.type -ne 'book' -or
      $null -eq $showBookJson.book) {
    throw 'CLI show book JSON contract failed'
  }

  $showPost = Invoke-WatchedProcess -FilePath $CliExe -ArgumentList @(
    $globalDbArgs + @('show', 'post', '2')
  ) -WorkingDirectory $AppDir -Name 'show-post' -TimeoutSec 60
  $showPostJson = $showPost.Stdout | ConvertFrom-Json
  if ($showPost.ExitCode -ne 0 -or $showPostJson.type -ne 'post' -or
      $null -eq $showPostJson.post) {
    throw 'CLI show post JSON contract failed'
  }

  $logFile = Join-Path $tempDir 'run.jsonl'
  @(
    '{"run":"20261019-000000-1","seq":1,"ts":"2026-10-19T00:00:00Z","level":"info","scope":"cli","event":"启动","detail":"","data":{}}',
    '{"run":"20261019-000000-1","seq":2,"ts":"2026-10-19T00:00:01Z","level":"ok","scope":"smoke","event":"完成","detail":"ok","data":{}}'
  ) -join "`n" | Set-Content -LiteralPath $logFile -NoNewline
  $logs = Invoke-WatchedProcess -FilePath $CliExe -ArgumentList @(
    '--json', '--no-log-file', 'logs', '--file', $logFile, '--level', 'ok'
  ) -WorkingDirectory $AppDir -Name 'logs-replay' -TimeoutSec 30
  $logsJson = $logs.Stdout | ConvertFrom-Json
  if ($logs.ExitCode -ne 0 -or $logsJson.count -ne 1 -or
      $logsJson.items[0].event -ne '完成') {
    throw 'CLI logs replay JSON contract failed'
  }

  $seed = Invoke-WatchedProcess -FilePath $CliExe -ArgumentList @(
    '--json', '--no-log-file', 'seed', '--dir', 'assets/seed', '--verify'
  ) -WorkingDirectory $AppDir -Name 'seed-inspect' -TimeoutSec 120
  $seedJson = $seed.Stdout | ConvertFrom-Json
  if ($seed.ExitCode -ne 0 -or $seedJson.ok -ne $true -or
      $null -eq $seedJson.packName) {
    throw 'CLI seed inspect JSON contract failed'
  }

  $gated = Invoke-WatchedProcess -FilePath $CliExe -ArgumentList @($globalDbArgs + @('collect', '--net')) `
    -WorkingDirectory $AppDir -Name 'network-gate' -TimeoutSec 30 -ClearNetworkGate
  $gatedJson = $gated.Stdout | ConvertFrom-Json
  if ($gated.ExitCode -ne 3 -or $gatedJson.error.type -ne 'gated') {
    throw 'CLI network gate exit/output contract failed'
  }

  $hashAfter = (Get-FileHash -LiteralPath $dbPath -Algorithm SHA256).Hash
  if ($hashAfter -ne $hashBefore) { throw 'Read-only CLI smoke commands modified the fixture database' }

  Write-Host '✓ CLI bundle: version, classify, doctor, hot/query/facets, show, logs, seed, collect plan, network gate, DB read-only all passed.' -ForegroundColor Green
  Write-Host "  Logs: $LogDir"
} finally {
  if ((Resolve-Path -LiteralPath $tempDir).Path.StartsWith(([System.IO.Path]::GetTempPath()), [StringComparison]::OrdinalIgnoreCase)) {
    Remove-Item -LiteralPath $tempDir -Recurse -Force
  }
}
