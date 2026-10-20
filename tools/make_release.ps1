#Requires -Version 7.0
<#
.SYNOPSIS
  扫书汇 BookSift —— Android release 一键打包与分发资产组装（路线图 Phase 5 第 4 项）。

.DESCRIPTION
  流程：
    preflight（flutter / 签名 / sqlite3 native 缓存）
    → flutter build apk --release（进程外看门狗，超时杀树 + 停 Gradle 守护进程）
    → apksigner 验签并记录证书指纹
    → 复制改名为更新检查契约名 + 生成 sha256
    → 组装 dist_release/（apk / seed zip / version.json）
    → 打印清单

  更新检查契约（只读对齐 app/lib/core/update/update_service.dart，勿改）：
    GitHub tag        = v{version}
    APK 资产名        = BookSift-android-v{version}.apk
    sha256 资产名     = BookSift-android-v{version}.apk.sha256（App 侧取内容中首个 64 位 hex）
    主源 owner/repo   = LinYuanovo/BookSift
                        （以 app/lib/core/update/update_controller.dart 的 kUpdateGithubOwner/Repo 为准，
                         两处需同步）
    备源 version.json = {"app":{version,version_code,notes,min_force,apk_url,apk_sha256,ios_url,
                                   ios_sha256,windows_url,windows_sha256,macos_url,macos_sha256,
                                   linux_url,linux_sha256},
                         "seed":{basic_version,full_version,full_urls,full_size,full_sha256,lanzou_backup}}

  本脚本**不做**：不创建远程仓库、不 push、不打 tag、不改 pubspec 版本号。
  -Publish 仅在已存在 git remote origin 且 gh 已登录时执行 gh release create，
  否则明确报错退出（exit 5）。

.PARAMETER Version
  版本号（如 1.0.0）。留空 = 从 app/pubspec.yaml 的 `version:` 解析（剥 +build 号）。
  显式传入且与 pubspec 不一致 → 报错退出（APK 内 versionName/versionCode 由 pubspec 决定，
  文件名与 tag 若对不上会破坏更新检查契约）。

.PARAMETER SkipSeed
  跳过种子包 zip 的复制与 sha256（只想快速验证 APK 时用）。

.PARAMETER Publish
  打包完成后执行 gh release create 并上传本版本发布包、校验文件及种子/分类器包。默认关。

.PARAMETER BuildTimeoutSec
  flutter build 的墙钟上限秒数，默认 1800（首次构建需下载 Gradle 依赖，别调太小）。

.EXAMPLE
  pwsh tools/make_release.ps1
.EXAMPLE
  pwsh tools/make_release.ps1 -SkipSeed
.EXAMPLE
  pwsh tools/make_release.ps1 -Version 1.0.0 -Publish
#>
[CmdletBinding()]
param(
  [string]$Version = '',

  [switch]$SkipSeed,

  [switch]$Publish,

  [ValidateRange(60, 7200)]
  [int]$BuildTimeoutSec = 1800
)

$ErrorActionPreference = 'Stop'

# 退出码：0 成功 / 2 参数错误 / 3 构建失败 / 4 preflight 受阻 / 5 发布受阻
# ── 路径与工具 ──────────────────────────────────────────────────────────
$RepoRoot  = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$AppDir    = Join-Path $RepoRoot 'app'
$DistDir   = Join-Path $RepoRoot 'dist_release'
$LogDir    = Join-Path $AppDir 'build\release_logs'
$AndroidDir = Join-Path $AppDir 'android'

$FlutterBat = 'C:\flutter\bin\flutter.bat'
$ApkSigner  = 'C:\Users\Administrator\AppData\Local\Android\Sdk\build-tools\35.0.0\apksigner.bat'
$Aapt2      = 'C:\Users\Administrator\AppData\Local\Android\Sdk\build-tools\35.0.0\aapt2.exe'
$GhExe      = 'C:\Program Files\GitHub CLI\gh.exe'
# 完整种子包（version.json seed.* 引用）：动态读 work/seed_pack/dist/compression_report.json 的
# full.final_zip 真值（审查 nit-8：硬编码会在种子重打后回退 version.json 的 full 包哈希）。
$SeedReportPath = Join-Path $RepoRoot 'work\seed_pack\dist\compression_report.json'
if (-not (Test-Path -LiteralPath $SeedReportPath)) {
  Write-Error "缺种子包压缩报告: $SeedReportPath（先跑 work/seed_pack/make_seed_pack.py）"
  exit 2
}
$SeedReport = Get-Content -LiteralPath $SeedReportPath -Raw | ConvertFrom-Json
$SeedPackVersion = [int]([System.IO.Path]::GetFileName([string]$SeedReport.tiers.full.final_zip.file) -replace '^seed_pack_v(\d+)\.zip$', '$1')
$SeedFullName = [System.IO.Path]::GetFileName([string]$SeedReport.tiers.full.final_zip.file)
$SeedFullSize   = [int64]$SeedReport.tiers.full.final_zip.size_bytes
$SeedFullSha256 = [string]$SeedReport.tiers.full.final_zip.sha256
if ($SeedFullSize -le 0 -or $SeedFullSha256 -notmatch '^[0-9a-f]{64}$') {
  Write-Error "compression_report.json 的 full.final_zip 字段异常: size=$SeedFullSize sha=$SeedFullSha256"
  exit 2
}

if (-not (Test-Path -LiteralPath (Join-Path $AppDir 'pubspec.yaml'))) {
  Write-Error "不是 Flutter 工程目录（缺 pubspec.yaml）: $AppDir"
  exit 2
}
foreach ($t in @(@('flutter', $FlutterBat), @('apksigner', $ApkSigner), @('aapt2', $Aapt2))) {
  if (-not (Test-Path -LiteralPath $t[1])) { Write-Error "$($t[0]) 不存在: $($t[1])"; exit 2 }
}
New-Item -ItemType Directory -Force -Path $DistDir | Out-Null
New-Item -ItemType Directory -Force -Path $LogDir  | Out-Null

function Write-Step { param([string]$Msg) Write-Host "`n── $Msg ──" -ForegroundColor Cyan }
function Get-Sha256 { param([string]$Path) (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLower() }
# sha256 旁文件：纯 64 位 hex 一行（App 侧用 [0-9a-fA-F]{64} 首个匹配取值）
function Write-Sha256File { param([string]$Target) Set-Content -LiteralPath "$Target.sha256" -Value (Get-Sha256 $Target) -Encoding ascii }

# ── 1. 版本号 ───────────────────────────────────────────────────────────
Write-Step '1/6 解析版本号'
$pubspecPath = Join-Path $AppDir 'pubspec.yaml'
$m = Select-String -LiteralPath $pubspecPath -Pattern '^version:\s*([0-9]+\.[0-9]+\.[0-9]+)(?:\+([0-9]+))?\s*$' | Select-Object -First 1
if ($null -eq $m) { Write-Error "无法从 pubspec.yaml 解析 version: $pubspecPath"; exit 2 }
$SpecVersion = $m.Matches[0].Groups[1].Value
$SpecBuild   = $m.Matches[0].Groups[2].Value
$BuildNumber = if ([string]::IsNullOrWhiteSpace($SpecBuild)) { 1 } else { [int]$SpecBuild }

& node (Join-Path $RepoRoot 'tools\render_docs.js')
if ($LASTEXITCODE -ne 0) {
  Write-Error '文档版本渲染失败，拒绝继续发布构建。'
  exit 2
}

if ([string]::IsNullOrWhiteSpace($Version)) {
  $Version = $SpecVersion
} elseif ($Version -ne $SpecVersion) {
  Write-Error "版本号不一致：-Version=$Version 但 app/pubspec.yaml 为 $SpecVersion+$SpecBuild。`nAPK 内 versionName/versionCode 由 pubspec 决定，改名不改实会破坏更新检查契约。`n请先改 pubspec.yaml 再重跑，或省略 -Version。"
  exit 2
}
Write-Host "  版本 $Version  versionCode $BuildNumber  →  tag v$Version / BookSift-android-v$Version.apk"

# ── 2. preflight ────────────────────────────────────────────────────────
Write-Step '2/6 preflight'
# 2a. release 签名在位？（缺失不阻断构建，gradle 会回退 debug 签名 → 但产物不可分发）
$KeyProps  = Join-Path $AndroidDir 'key.properties'
$Signed    = $false
if (Test-Path -LiteralPath $KeyProps) {
  $kp = @{}
  Get-Content -LiteralPath $KeyProps | ForEach-Object { $k, $v = $_ -split '=', 2; if ($k) { $kp[$k.Trim()] = ($v ?? '').Trim() } }
  $storeFile = Join-Path (Join-Path $AndroidDir 'app') ($kp['storeFile'] ?? '')
  if (($kp['storeFile']) -and (Test-Path -LiteralPath $storeFile) -and $kp['keyAlias']) {
    $Signed = $true
    Write-Host "  ✓ release 签名：alias=$($kp['keyAlias'])  keystore=$(Split-Path $storeFile -Leaf)" -ForegroundColor Green
  } else {
    Write-Host "  ! key.properties 存在但 keystore 不在位 → 将回退 debug 签名" -ForegroundColor Yellow
  }
} else {
  Write-Host "  ! 缺 $KeyProps → 将回退 debug 签名（产物不可分发）" -ForegroundColor Yellow
}
Write-Host "    签名生成与备份要求见 docs/发布指南.md §2"

# 2b. sqlite3 native assets 缓存：Dart 的 HttpClient 不走系统代理，
#     构建钩子下载 libsqlite3.<abi>.android.so 在无直连 GitHub 的机器上必失败。
#     缓存命中即跳过下载 → 这里提前检查，避免 4 分钟后才看到晦涩的 SocketException。
function Test-Sqlite3Cache {
  $pc = Join-Path $AppDir '.dart_tool\package_config.json'
  if (-not (Test-Path -LiteralPath $pc)) { return @{ Ok = $false; Detail = 'package_config.json 缺失（先跑 flutter pub get）'; Missing = @() } }
  $sq = ((Get-Content -LiteralPath $pc -Raw | ConvertFrom-Json).packages | Where-Object { $_.name -eq 'sqlite3' } | Select-Object -First 1)
  if ($null -eq $sq) { return @{ Ok = $true; Detail = '未依赖 sqlite3'; Missing = @() } }
  $pkgRoot  = ([System.Uri]$sq.rootUri).LocalPath
  $hashFile = Join-Path $pkgRoot 'lib\src\hook\asset_hashes.dart'
  $shared   = Join-Path $AppDir '.dart_tool\hooks_runner\shared\sqlite3\build'
  if (-not (Test-Path -LiteralPath $hashFile)) { return @{ Ok = $true; Detail = '该版本无 asset_hashes.dart（可能改为本地编译）'; Missing = @() } }
  $missing = [System.Collections.Generic.List[string]]::new()
  $urls    = [System.Collections.Generic.List[string]]::new()
  $raw  = Get-Content -LiteralPath $hashFile -Raw
  $tagM = [regex]::Match($raw, "releaseTag\s*=\s*'([^']+)'")
  $tag  = if ($tagM.Success) { $tagM.Groups[1].Value } else { 'null' }
  $re = [regex]"'(libsqlite3\.(?:arm|arm64|x64)\.android\.so)':\s*'([0-9a-fA-F]{64})'"
  # 本机 pub cache 的 3.5.2 哈希表与实际下载字节不一致；优先接受已知可用的下一哈希目录，
  # 由 APK 原生资产闸门在构建后再次校验 ABI 文件是否齐全。
  $knownGood = @{
    'libsqlite3.arm.android.so'   = '5f331b44ef2549f1e3fa2153ad22d60d85c5a43766e4690a29cc49a0652db772'
    'libsqlite3.arm64.android.so' = '081df67ee9ab852daea6a0679427e90fc89a0245d06f93dafe2309875c609c5c'
    'libsqlite3.x64.android.so'   = 'c773c3a25e4c11a450cc700ac95d665c3a1ae75ad426a204fc9b7a7a69b0e191'
  }
  foreach ($mm in $re.Matches($raw)) {
    $name = $mm.Groups[1].Value; $hash = $mm.Groups[2].Value.ToLower()
    $cached = Join-Path $shared ("download-" + $hash.Substring(0, 8)) 'libsqlite3.so'
    $fallbackHash = $knownGood[$name]
    if (-not (Test-Path -LiteralPath $cached) -and $fallbackHash) {
      $fallback = Join-Path $shared ("download-" + $fallbackHash.Substring(0, 8)) 'libsqlite3.so'
      if ((Test-Path -LiteralPath $fallback) -and
          (Get-Sha256 $fallback) -eq $fallbackHash) {
        $cached = $fallback
      }
    }
    if (-not (Test-Path -LiteralPath $cached)) {
      $missing.Add($name)
      $urls.Add("https://github.com/simolus3/sqlite3.dart/releases/download/$tag/$name")
    }
  }
  if ($missing.Count -eq 0) { return @{ Ok = $true; Detail = 'arm/arm64/x64 三个 libsqlite3.so 均已缓存'; Missing = @() } }
  return @{ Ok = $false; Detail = "缺 $($missing -join ', ')"; Missing = $missing; Urls = $urls; Shared = $shared; Hashes = $hashFile }
}
$cache = Test-Sqlite3Cache
if ($cache.Ok) {
  Write-Host "  ✓ sqlite3 native 缓存：$($cache.Detail)" -ForegroundColor Green
} else {
  Write-Host "  ✗ sqlite3 native 缓存$($cache.Detail)" -ForegroundColor Red
  Write-Host "    Dart 构建钩子不走系统代理，无 GitHub 直连时必失败。手工预置（PowerShell 走系统代理）：" -ForegroundColor Yellow
  Write-Host "      `$shared = '$($cache.Shared)'"
  Write-Host "      按 $($cache.Hashes) 里的 sha256，逐个下载下列文件并校验后存为 `$shared\download-<sha256前8位>\libsqlite3.so ："
  foreach ($u in $cache.Urls) { Write-Host "        Invoke-WebRequest -Uri '$u' -OutFile `$env:TEMP\x.so" }
  Write-Host "    详见 docs/发布指南.md §7 故障排查。"
  exit 4
}

# ── 3. 构建 ─────────────────────────────────────────────────────────────
Write-Step "3/6 flutter build apk --release（墙钟上限 ${BuildTimeoutSec}s）"
# Flutter 的 native-assets 目录不是 Gradle 的完整输入，残留的 Android
# 增量目录可能让 assembleRelease 复用一份没有 sqlite3 的空结果。只清理
# Android 构建侧的生成物，保留 Windows native_assets 给本地测试使用。
$flutterAssetsDir = Join-Path $AppDir 'build\flutter_assets'
if (Test-Path -LiteralPath $flutterAssetsDir) {
  Remove-Item -LiteralPath $flutterAssetsDir -Recurse -Force -ErrorAction Stop
}
$androidNativeAssets = Join-Path $AppDir 'build\native_assets\android'
$androidReleaseBuildIdFile = Join-Path $AppDir 'build\app\intermediates\flutter\release\.last_build_id'
if (Test-Path -LiteralPath $androidReleaseBuildIdFile) {
  $androidReleaseBuildId = (Get-Content -LiteralPath $androidReleaseBuildIdFile -Raw).Trim()
  if ($androidReleaseBuildId -notmatch '^[0-9a-f]{32}$') {
    Write-Host '  ✗ Flutter Android release 构建 ID 格式无效，拒绝清理缓存。' -ForegroundColor Red
    exit 3
  }
  $installCodeAssetsStamp = Join-Path $AppDir ".dart_tool\flutter_build\$androidReleaseBuildId\install_code_assets.stamp"
  if (Test-Path -LiteralPath $installCodeAssetsStamp) {
    Remove-Item -LiteralPath $installCodeAssetsStamp -Force -ErrorAction Stop
  }
}
if (Test-Path -LiteralPath $androidNativeAssets) {
  Remove-Item -LiteralPath $androidNativeAssets -Recurse -Force -ErrorAction Stop
}
Write-Host '  ✓ 已清理共享 Flutter assets / Android native-assets 安装缓存与 ABI 目录' -ForegroundColor Green
$stamp   = Get-Date -Format 'yyyyMMdd-HHmmss'
$outLog  = Join-Path $LogDir "release-$Version-$stamp.out.log"
$errLog  = Join-Path $LogDir "release-$Version-$stamp.err.log"
$env:JAVA_HOME = 'C:\Program Files\Microsoft\jdk-21.0.12.101-hotspot'

$started = Get-Date
$proc = Start-Process -FilePath $FlutterBat -ArgumentList @('build', 'apk', '--release') `
  -WorkingDirectory $AppDir -NoNewWindow -PassThru `
  -RedirectStandardOutput $outLog -RedirectStandardError $errLog
Write-Host "  PID=$($proc.Id)  日志 $outLog"
$exited = $false; $elapsed = 0
while (-not $exited -and $elapsed -lt $BuildTimeoutSec) {
  $slice = [Math]::Min(30, [Math]::Max(1, $BuildTimeoutSec - $elapsed))
  $exited = $proc.WaitForExit($slice * 1000)
  $elapsed = [int]((Get-Date) - $started).TotalSeconds
  if (-not $exited -and $elapsed -lt $BuildTimeoutSec) {
    $last = (Get-Content -LiteralPath $outLog -Tail 1 -ErrorAction SilentlyContinue) -join ''
    if ($last.Length -gt 90) { $last = $last.Substring(0, 90) + '…' }
    Write-Host "  …${elapsed}s / ${BuildTimeoutSec}s  $last"
  }
}
if (-not $proc.HasExited) {
  & taskkill.exe /PID $proc.Id /T /F 2>&1 | Out-Null
  Push-Location $AndroidDir; & .\gradlew.bat --stop 2>&1 | Out-Null; Pop-Location
  Write-Host "  ✗ 构建超时 ${BuildTimeoutSec}s，已杀进程树并停 Gradle 守护进程" -ForegroundColor Red
  Get-Content -LiteralPath $outLog -Tail 40 -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "    $_" }
  exit 3
}
$buildCode = $proc.ExitCode
Write-Host "  flutter exit=$buildCode  用时 ${elapsed}s"
if ($buildCode -ne 0) {
  # Dart 编译错误落 stderr，Gradle 包装信息落 stdout → 先打 stderr，别被 gradle 尾部盖住。
  Write-Host "  ✗ 构建失败 exit=$buildCode。stderr 尾部（Dart 编译错误在此）：" -ForegroundColor Red
  Get-Content -LiteralPath $errLog -Tail 80 -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "    $_" }
  Write-Host "  ── stdout 尾部（Gradle）──" -ForegroundColor Yellow
  Get-Content -LiteralPath $outLog -Tail 25 -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "    $_" }
  Write-Host "  判读：错误定位在 app/lib/** = 并行开发的 Dart 编译错误（非本脚本/签名问题），修好后重跑；" -ForegroundColor Yellow
  Write-Host "        定位在 app/android/** 才是打包侧问题。" -ForegroundColor Yellow
  Write-Host "  注：日志里 Kotlin 'different roots' 增量缓存报错是跨盘（C: pub cache ↔ E: 工程）噪声，" -ForegroundColor Yellow
  Write-Host "      守护进程会自动回退非增量编译，不影响产物。" -ForegroundColor Yellow
  exit 3
}
$builtApk = Join-Path $AppDir 'build\app\outputs\flutter-apk\app-release.apk'
if (-not (Test-Path -LiteralPath $builtApk)) { Write-Error "构建报成功但找不到产物: $builtApk"; exit 3 }
Select-String -LiteralPath $outLog -Pattern 'Built build' -SimpleMatch | Select-Object -Last 1 | ForEach-Object { Write-Host "  $($_.Line.Trim())" -ForegroundColor Green }

# native-assets 缺失时 APK 仍可能成功打包，但 drift/sqlite3 会在启动时找不到
# 动态库，最终表现为页面空白或数据库打不开。验证发布包而不是只验证构建退出码。
Add-Type -AssemblyName System.IO.Compression.FileSystem
$requiredSqliteAssets = @(
  'lib/armeabi-v7a/libsqlite3.so',
  'lib/arm64-v8a/libsqlite3.so',
  'lib/x86_64/libsqlite3.so'
)
$apkZip = [System.IO.Compression.ZipFile]::OpenRead($builtApk)
try {
  $apkEntries = @($apkZip.Entries | ForEach-Object { $_.FullName })
} finally {
  $apkZip.Dispose()
}
$missingSqliteAssets = @($requiredSqliteAssets | Where-Object { $_ -notin $apkEntries })
if ($missingSqliteAssets.Count -gt 0) {
  Write-Host '  ✗ APK 原生资产闸门失败：缺少 sqlite3 ABI 库：' -ForegroundColor Red
  $missingSqliteAssets | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
  Write-Host '    已拒绝组装 dist_release；检查 build/native_assets/android/jniLibs/lib 和构建日志。' -ForegroundColor Yellow
  exit 3
}
Write-Host '  ✓ APK 原生资产闸门：arm/arm64/x86_64 三份 libsqlite3.so 均在包内' -ForegroundColor Green

# ── 4. 验签 ─────────────────────────────────────────────────────────────
Write-Step '4/6 apksigner 验签'
$certLog = Join-Path $LogDir "certs-$Version-$stamp.txt"
& $ApkSigner verify --print-certs --verbose $builtApk *> $certLog
$verifyCode = $LASTEXITCODE
Get-Content -LiteralPath $certLog | Where-Object { $_ -match 'Signer|Verifies|Verified using v[123] scheme|Number of signers' } | ForEach-Object { Write-Host "  $_" }
if ($verifyCode -ne 0) { Write-Host "  ✗ apksigner 验签失败 exit=$verifyCode" -ForegroundColor Red; exit 3 }
$certDn = (Select-String -LiteralPath $certLog -Pattern 'certificate DN:\s*(.+)$' | Select-Object -First 1).Matches[0].Groups[1].Value.Trim()
$certFp = (Select-String -LiteralPath $certLog -Pattern 'certificate SHA-256 digest:\s*([0-9a-f]{64})' | Select-Object -First 1).Matches[0].Groups[1].Value
if ($Signed -and $certDn -notmatch 'BookSift') {
  Write-Host "  ✗ key.properties 在位但证书 DN=$certDn —— 疑似回退 debug 签名，不可分发" -ForegroundColor Red
  exit 3
}
Write-Host "  ✓ 证书 DN=$certDn" -ForegroundColor Green
Write-Host "  ✓ 证书 SHA-256=$certFp" -ForegroundColor Green

# 权限闸门：Flutter 模板只给 debug/profile 清单加 INTERNET，main/ 漏声明会让 release
# 产物静默失去全部网络能力（采集 / 在线搜索 / 更新检查 / 网络图片）。实测踩过，故设为硬闸门。
$perms = (& $Aapt2 dump permissions $builtApk 2>&1 | Out-String)
if ($perms -notmatch 'android\.permission\.INTERNET') {
  Write-Host "  ✗ release APK 缺 android.permission.INTERNET —— 产物网络功能全废，拒绝发布。" -ForegroundColor Red
  Write-Host "    修：在 app/android/app/src/main/AndroidManifest.xml 的 <manifest> 下加" -ForegroundColor Yellow
  Write-Host "        <uses-permission android:name=`"android.permission.INTERNET`"/>" -ForegroundColor Yellow
  exit 3
}
Write-Host "  ✓ 权限闸门：INTERNET 已声明" -ForegroundColor Green

# ── 5. 组装 dist_release ────────────────────────────────────────────────
Write-Step '5/6 组装 dist_release/'
$apkName  = "BookSift-android-v$Version.apk"
$apkDest  = Join-Path $DistDir $apkName
Copy-Item -LiteralPath $builtApk -Destination $apkDest -Force
Write-Sha256File $apkDest
$apkSha = Get-Sha256 $apkDest
$apkSize = (Get-Item -LiteralPath $apkDest).Length
Write-Host "  ✓ $apkName  $([math]::Round($apkSize/1MB,2)) MiB" -ForegroundColor Green
Write-Host "    sha256 $apkSha"

$seedName = ''; $seedSha = ''; $seedSize = 0
if ($SkipSeed) {
  Write-Host "  - 跳过种子包（-SkipSeed）" -ForegroundColor Yellow
} else {
  # 用 App 内置的 deflate 重打包版，不用 work/seed_pack/dist/ 的 Zip-LZMA 原版：
  # Dart package:archive 无 Zip-LZMA 解码器，LZMA 版 App 导不进去（见 app/assets/seed/manifest.json 的 repack_reason）。
  $seedSrc = Join-Path $AppDir 'assets\seed\seed_pack_lite_v1.zip'
  if (-not (Test-Path -LiteralPath $seedSrc)) {
    Write-Error "缺种子包源文件: $seedSrc（用 -SkipSeed 跳过）"; exit 2
  }
  $seedName = "seed_pack_lite_v$SeedPackVersion.zip"
  $seedDest = Join-Path $DistDir $seedName
  Copy-Item -LiteralPath $seedSrc -Destination $seedDest -Force
  Write-Sha256File $seedDest
  $seedSha  = Get-Sha256 $seedDest
  $seedSize = (Get-Item -LiteralPath $seedDest).Length
  Write-Host "  ✓ $seedName  $([math]::Round($seedSize/1MB,2)) MiB (deflate, App 可导入)" -ForegroundColor Green
  Write-Host "    sha256 $seedSha"
}

# version.json 备源：结构照 update_service.dart 的 StaticJsonSource 解析口径还原。
# 平台下载 URL 均指向本项目 GitHub Releases 对应版本的固定命名资产。
# 本脚本只在本机生成 Android 包；其他平台的资产由对应构建 job 生成。
$notesPath = Join-Path $DistDir 'RELEASE_NOTES.md'
$notesLine = ''
if (Test-Path -LiteralPath $notesPath) {
  $notesLine = (Get-Content -LiteralPath $notesPath |
    Where-Object { $_.Trim() -ne '' -and -not $_.StartsWith('#') -and -not $_.StartsWith('-') } |
    Select-Object -First 1) ?? ''
  if ($notesLine.Length -gt 200) { $notesLine = $notesLine.Substring(0, 200) + '…' }
} else {
  Write-Host "  ! 缺 RELEASE_NOTES.md（version.json 的 notes 将为空，-Publish 会失败）" -ForegroundColor Yellow
}

$versionJson = [ordered]@{
  _note = '平台下载 URL 均为本项目 GitHub Releases 真实直链；苹果包未签名；min_force 留空 = 不强制更新；lanzou_backup 留空 = 不展示对应入口。'
  app   = [ordered]@{
    version      = $Version
    version_code = $BuildNumber
    notes        = $notesLine
    min_force    = ''
    apk_url      = "https://github.com/LinYuanovo/BookSift/releases/download/v$Version/$apkName"
    apk_sha256   = $apkSha
    ios_url      = "https://github.com/LinYuanovo/BookSift/releases/download/v$Version/BookSift-ios-v$Version.ipa"
    ios_sha256   = ''
    windows_url  = "https://github.com/LinYuanovo/BookSift/releases/download/v$Version/BookSift-windows-x64-v$Version.zip"
    windows_sha256 = ''
    macos_url    = "https://github.com/LinYuanovo/BookSift/releases/download/v$Version/BookSift-macos-universal-v$Version.zip"
    macos_sha256 = ''
    linux_url    = "https://github.com/LinYuanovo/BookSift/releases/download/v$Version/BookSift-linux-x64-v$Version.tar.gz"
    linux_sha256 = ''
  }
  seed  = [ordered]@{
    basic_version = $SeedPackVersion
    full_version  = $SeedPackVersion
    full_urls     = @("https://github.com/LinYuanovo/BookSift/releases/download/seed-v$SeedPackVersion/$SeedFullName")
    full_size     = $SeedFullSize
    full_sha256   = $SeedFullSha256
    lanzou_backup = ''
  }
}
$vjPath = Join-Path $DistDir 'version.json'
$versionJson | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $vjPath -Encoding utf8
Write-Host "  ✓ version.json（app.version=$Version / version_code=$BuildNumber / apk_sha256 已填真值 / 五个平台 URL 已填写）" -ForegroundColor Green

# 分类规则源码与回归测试单独随包分发，便于审查和独立复跑。
Write-Step '分类规则源码与回归测试包'
& (Join-Path $PSScriptRoot 'pack_classifier_sources.ps1') -Version $Version -DistDir $DistDir

# ── 6. 清单 ─────────────────────────────────────────────────────────────
Write-Step '6/6 dist_release 清单'
Get-ChildItem -LiteralPath $DistDir -File | Sort-Object Name | ForEach-Object {
  $sz = if ($_.Length -gt 1MB) { "$([math]::Round($_.Length/1MB,2)) MiB" } else { "$($_.Length) B" }
  Write-Host ("  {0,-34} {1,12}" -f $_.Name, $sz)
}
Write-Host ''
Write-Host "  下一步（发布）：" -ForegroundColor Cyan
Write-Host "    1. 建 repo → push → git tag v$Version → git push origin v$Version（也可由 GitHub Actions（.github/workflows/build-release.yml）在 tag 推送时自动打包发布）"
Write-Host "    2. pwsh tools/make_release.ps1 -Publish"
Write-Host "    3. 部署 version.json 到静态托管（五个平台 URL 均指向 v$Version Release 资产），设置页填该 URL 作备源"
Write-Host "    完整步骤见 docs/发布指南.md"

# ── 可选发布 ────────────────────────────────────────────────────────────
if ($Publish) {
  Write-Step '发布（-Publish）'
  if (-not (Test-Path -LiteralPath $notesPath)) { Write-Error "缺 RELEASE_NOTES.md，无法生成 release 说明"; exit 5 }
  Push-Location $RepoRoot
  try {
    $remote = (git remote get-url origin 2>$null)
    if ([string]::IsNullOrWhiteSpace($remote)) {
      Write-Host "  ✗ 本仓库没有 git remote origin —— 拒绝发布。" -ForegroundColor Red
      Write-Host "    先建远程仓库并关联（见 docs/发布指南.md §4）：" -ForegroundColor Yellow
      Write-Host "      gh repo create BookSift --public --source=. --remote=origin"
      Write-Host "      git push -u origin main && git tag v$Version && git push origin v$Version"
      exit 5
    }
    Write-Host "  remote origin = $remote"
    if (-not (Test-Path -LiteralPath $GhExe)) { Write-Error "gh 不在预期路径: $GhExe"; exit 5 }
    & $GhExe auth status 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Error 'gh 未登录，先 gh auth login'; exit 5 }
    # 发布严格使用本版本平台包及其校验文件，不扫入本地演示和旧版本文件。
    . (Join-Path $PSScriptRoot 'release_assets.ps1')
    $assets = @(Get-BookSiftReleaseAssets -DistDir $DistDir -Version $Version -SeedPackVersion $SeedPackVersion)
    if (-not ($assets | Where-Object { [System.IO.Path]::GetFileName($_) -eq "BookSift-android-v$Version.apk" })) {
      Write-Error "缺少本版本 Android 更新资产 BookSift-android-v$Version.apk，拒绝发布。"
      exit 5
    }
    Write-Host "  上传 $($assets.Count) 个资产 → tag v$Version"
    & $GhExe release create "v$Version" @assets --title "扫书汇 v$Version" --notes-file $notesPath
    if ($LASTEXITCODE -ne 0) { Write-Error "gh release create 失败 exit=$LASTEXITCODE"; exit 5 }
    Write-Host "  ✓ 已发布 tag v$Version" -ForegroundColor Green
    Write-Host "  验证 App 内更新检查：安装更低版本的 APK → 我的 → 关于 → 检查更新，应命中 GitHub 主源。" -ForegroundColor Cyan
  } finally { Pop-Location }
}

Write-Host ''
Write-Host "✓ 完成：dist_release/ 已就绪（v$Version，签名=$([bool]$Signed)）" -ForegroundColor Green
exit 0
