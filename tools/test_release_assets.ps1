#Requires -Version 7.0
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'release_assets.ps1')

$temp = Join-Path ([System.IO.Path]::GetTempPath()) "booksift-release-assets-$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $temp | Out-Null
try {
  $expected = @(
    'android-v1.2.3.apk',
    'android-v1.2.3.apk.sha256',
    'seed_pack_lite_v1.zip',
    'seed_pack_lite_v1.zip.sha256',
    'classifier-source-v1.2.3.zip',
    'classifier-source-v1.2.3.zip.sha256'
  )
  foreach ($name in @(
    'android-v1.2.3.apk',
    'android-v1.2.3.apk.sha256',
    'seed_pack_lite_v1.zip',
    'seed_pack_lite_v1.zip.sha256',
    'classifier-source-v1.2.3.zip',
    'classifier-source-v1.2.3.zip.sha256',
    'app-v1.2.3.apk',
    'android-v1.2.2.apk',
    'booksift-promo-video.mp4',
    'RELEASE_NOTES.md',
    'version.json'
  )) {
    Set-Content -LiteralPath (Join-Path $temp $name) -Value 'fixture' -NoNewline
  }

  $actual = @(Get-BookSiftReleaseAssets -DistDir $temp -Version '1.2.3' |
    ForEach-Object { [System.IO.Path]::GetFileName($_) })
  if (Compare-Object -ReferenceObject $expected -DifferenceObject $actual) {
    throw "Unexpected release assets: $($actual -join ', ')"
  }

  'RELEASE_ASSET_SELECTION=PASS'
} finally {
  Remove-Item -LiteralPath $temp -Recurse -Force
}
