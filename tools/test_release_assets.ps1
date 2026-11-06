#Requires -Version 7.0
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'release_assets.ps1')

$temp = Join-Path ([System.IO.Path]::GetTempPath()) "booksift-release-assets-$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $temp | Out-Null
try {
  $expected = @(
    'BookSift-android-v1.2.3.apk',
    'seed_pack_lite_v1.zip',
    'classifier-source-v1.2.3.zip',
    'version.json'
  )
  foreach ($name in @(
    'BookSift-android-v1.2.3.apk',
    'BookSift-android-v1.2.3.apk.sha256',
    'seed_pack_lite_v1.zip',
    'seed_pack_lite_v1.zip.sha256',
    'classifier-source-v1.2.3.zip',
    'classifier-source-v1.2.3.zip.sha256',
    'app-v1.2.3.apk',
    'BookSift-android-v1.2.2.apk',
    'booksift-promo-video.mp4',
    'RELEASE_NOTES.md',
    'version.json'
  )) {
    Set-Content -LiteralPath (Join-Path $temp $name) -Value 'fixture' -NoNewline
  }
  $hash = (Get-FileHash -LiteralPath (Join-Path $temp 'BookSift-android-v1.2.3.apk')).Hash.ToLowerInvariant()
  $manifest = @{
    app = @{ version = '1.2.3'; apk_sha256 = $hash }
    assets = @{
      'seed_pack_lite_v1.zip' = @{ sha256 = $hash }
      'classifier-source-v1.2.3.zip' = @{ sha256 = $hash }
    }
  }
  $manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $temp 'version.json')

  $actual = @(Get-BookSiftReleaseAssets -DistDir $temp -Version '1.2.3' -SeedPackVersion 1 |
    ForEach-Object { [System.IO.Path]::GetFileName($_) })
  if (Compare-Object -ReferenceObject $expected -DifferenceObject $actual) {
    throw "Unexpected release assets: $($actual -join ', ')"
  }
  Set-Content -LiteralPath (Join-Path $temp 'BookSift-android-v1.2.3.apk') -Value 'changed'
  $rejected = $false
  try {
    Get-BookSiftReleaseAssets -DistDir $temp -Version '1.2.3' -SeedPackVersion 1 | Out-Null
  } catch { $rejected = $true }
  if (-not $rejected) { throw 'Accepted an APK with a mismatched manifest hash' }

  'RELEASE_ASSET_SELECTION=PASS'
} finally {
  Remove-Item -LiteralPath $temp -Recurse -Force
}
