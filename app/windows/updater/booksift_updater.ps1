# BookSift desktop update helper.
# The running application exits before this script replaces files.
param(
  [string]$Archive,
  [string]$Bundle,
  [string]$ExeName,
  [int]$AppPid,
  [string]$CleanupRoot
)

if (-not [string]::IsNullOrWhiteSpace($CleanupRoot)) {
  Start-Sleep -Seconds 3
  Remove-Item -LiteralPath $CleanupRoot -Recurse -Force -ErrorAction SilentlyContinue
  exit 0
}
if ([string]::IsNullOrWhiteSpace($Archive) -or
    [string]::IsNullOrWhiteSpace($Bundle) -or
    [string]::IsNullOrWhiteSpace($ExeName) -or
    $AppPid -le 0) {
  exit 2
}

$ErrorActionPreference = 'Stop'
$bundlePath = [IO.Path]::GetFullPath($Bundle)
$archivePath = [IO.Path]::GetFullPath($Archive)
$bundleParent = Split-Path -Parent $bundlePath
if ([string]::IsNullOrWhiteSpace($bundleParent) -or
    -not (Test-Path -LiteralPath $bundleParent -PathType Container)) {
  exit 3
}
$executablePath = Join-Path $bundlePath $ExeName
$helperRoot = Join-Path ([IO.Path]::GetTempPath()) ('booksift-update-' + [Guid]::NewGuid().ToString('N'))
$helperCopy = Join-Path $helperRoot 'booksift_updater.ps1'
$staging = Join-Path $helperRoot 'staging'
$backup = Join-Path $helperRoot 'backup'
$logPath = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'BooksSift\update.log'

New-Item -ItemType Directory -Force -Path $helperRoot, $staging, (Split-Path -Parent $logPath) | Out-Null
Copy-Item -LiteralPath $PSCommandPath -Destination $helperCopy -Force

function Write-UpdateLog([string]$message) {
  Add-Content -LiteralPath $logPath -Value ('[{0:O}] {1}' -f (Get-Date), $message) -Encoding utf8
}

try {
  for ($i = 0; $i -lt 120; $i++) {
    if (-not (Get-Process -Id $AppPid -ErrorAction SilentlyContinue)) { break }
    Start-Sleep -Milliseconds 250
  }
  if (Get-Process -Id $AppPid -ErrorAction SilentlyContinue) {
    throw 'BookSift did not exit within 30 seconds.'
  }

  if (-not (Test-Path -LiteralPath $executablePath -PathType Leaf)) {
    throw "Installed executable is missing: $executablePath"
  }
  Write-UpdateLog "Extracting $archivePath"
  Expand-Archive -LiteralPath $archivePath -DestinationPath $staging -Force
  $source = $staging
  if (-not (Test-Path -LiteralPath (Join-Path $source $ExeName))) {
    $candidate = Get-ChildItem -LiteralPath $staging -Directory |
      Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName $ExeName) } |
      Select-Object -First 1
    if ($null -ne $candidate) { $source = $candidate.FullName }
  }
  if (-not (Test-Path -LiteralPath (Join-Path $source $ExeName))) {
    throw "Update archive does not contain $ExeName."
  }

  $bundleMoved = $false
  if (Test-Path -LiteralPath $bundlePath) {
    Move-Item -LiteralPath $bundlePath -Destination $backup
    $bundleMoved = $true
  }
  try {
    Move-Item -LiteralPath $source -Destination $bundlePath
    $executable = Join-Path $bundlePath $ExeName
    Write-UpdateLog "Replaced $bundlePath"
    try {
      Start-Process -FilePath $executable -WorkingDirectory $bundlePath
      Write-UpdateLog "Restarted $executable"
    } catch {
      Write-UpdateLog "Replacement succeeded, restart failed: $($_.Exception.Message)"
    }
  } catch {
    if (Test-Path -LiteralPath $bundlePath) {
      Remove-Item -LiteralPath $bundlePath -Recurse -Force
    }
    if ($bundleMoved -and (Test-Path -LiteralPath $backup)) {
      Move-Item -LiteralPath $backup -Destination $bundlePath
    }
    throw
  }
  Start-Process -FilePath 'powershell.exe' -WindowStyle Hidden -ArgumentList @(
    '-NoProfile', '-File', $helperCopy, '-CleanupRoot', $helperRoot
  )
} catch {
  Write-UpdateLog $_.Exception.ToString()
  $executable = Join-Path $bundlePath $ExeName
  if (Test-Path -LiteralPath $executable) {
    Start-Process -FilePath $executable -WorkingDirectory $bundlePath
  }
  exit 1
}

exit 0
