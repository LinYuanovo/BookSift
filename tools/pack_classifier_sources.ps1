#Requires -Version 7.0
[CmdletBinding()]
param(
  [string]$Version = '',
  [string]$DistDir = ''
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$appRoot = Join-Path $repoRoot 'app'
if ([string]::IsNullOrWhiteSpace($Version)) {
  $versionLine = Select-String -LiteralPath (Join-Path $appRoot 'pubspec.yaml') -Pattern '^version:' | Select-Object -First 1
  if ($null -eq $versionLine -or $versionLine.Line -notmatch '^version:\s*([0-9]+\.[0-9]+\.[0-9]+)') {
    throw '无法从 app/pubspec.yaml 解析版本号。'
  }
  $Version = $Matches[1]
}
if ([string]::IsNullOrWhiteSpace($DistDir)) {
  $DistDir = Join-Path $repoRoot 'dist_release'
}
New-Item -ItemType Directory -Force -Path $DistDir | Out-Null
$distPath = (Resolve-Path -LiteralPath $DistDir).Path
$packName = "classifier-source-v$Version"
$zipPath = Join-Path $distPath "$packName.zip"
$hashPath = "$zipPath.sha256"
$resolvedZipPath = [System.IO.Path]::GetFullPath($zipPath)
if (-not $resolvedZipPath.StartsWith($distPath + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
  throw "分类源码包目标越出 dist_release：$resolvedZipPath"
}
$stageRoot = Join-Path ([System.IO.Path]::GetTempPath()) "booksift-classifier-$([guid]::NewGuid().ToString('N'))"
$packageRoot = Join-Path $stageRoot $packName

try {
  $files = @(
    @{ Source = (Join-Path $appRoot 'lib/classify'); Relative = 'lib/classify' },
    @{ Source = (Join-Path $appRoot 'assets/dict/book_dict.txt'); Relative = 'assets/dict/book_dict.txt' },
    @{ Source = (Join-Path $appRoot 'lib/data/repo/queries.dart'); Relative = 'lib/data/repo/queries.dart' },
    @{ Source = (Join-Path $appRoot 'test/classify/entry_kind_test.dart'); Relative = 'app_test/classify/entry_kind_test.dart' },
    @{ Source = (Join-Path $PSScriptRoot 'classifier_pack/README.md'); Relative = 'README.md' },
    @{ Source = (Join-Path $PSScriptRoot 'classifier_pack/test/entry_kind_smoke.dart'); Relative = 'test/entry_kind_smoke.dart' }
  )
  foreach ($item in $files) {
    if (-not (Test-Path -LiteralPath $item.Source)) { throw "分类源码包缺少必需文件：$($item.Source)" }
    $target = Join-Path $packageRoot $item.Relative
    $parent = Split-Path -Parent $target
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
    if ((Get-Item -LiteralPath $item.Source).PSIsContainer) {
      Copy-Item -LiteralPath $item.Source -Destination $target -Recurse -Force
    } else {
      Copy-Item -LiteralPath $item.Source -Destination $target -Force
    }
  }
  if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
  Compress-Archive -Path (Join-Path $packageRoot '*') -DestinationPath $zipPath -CompressionLevel Optimal
  $sha = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
  Set-Content -LiteralPath $hashPath -Value $sha -Encoding ascii
  Write-Host "  ✓ $([System.IO.Path]::GetFileName($zipPath))  $((Get-Item -LiteralPath $zipPath).Length) B"
  Write-Host "    sha256 $sha"
} finally {
  if (Test-Path -LiteralPath $stageRoot) {
    $resolvedStage = [System.IO.Path]::GetFullPath($stageRoot)
    $tempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
    if (-not $resolvedStage.StartsWith($tempRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
      throw "拒绝清理临时目录之外的路径：$resolvedStage"
    }
    Remove-Item -LiteralPath $resolvedStage -Recurse -Force
  }
}
