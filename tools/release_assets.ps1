function Get-BookSiftReleaseAssets {
  param(
    [Parameter(Mandatory)][string]$DistDir,
    [Parameter(Mandatory)][string]$Version
  )

  $names = @(
    "android-v$Version.apk",
    "windows-x64-v$Version.zip",
    "linux-x64-v$Version.tar.gz",
    "ios-v$Version.ipa",
    "macos-universal-v$Version.zip",
    'seed_pack_lite_v1.zip',
    "classifier-source-v$Version.zip"
  )
  $assets = [System.Collections.Generic.List[string]]::new()
  foreach ($name in $names) {
    $path = Join-Path $DistDir $name
    if (Test-Path -LiteralPath $path -PathType Leaf) {
      $assets.Add((Resolve-Path -LiteralPath $path).Path)
      $checksum = "$path.sha256"
      if (-not (Test-Path -LiteralPath $checksum -PathType Leaf)) {
        throw "Missing checksum for release asset: $name"
      }
      $assets.Add((Resolve-Path -LiteralPath $checksum).Path)
    }
  }
  return $assets.ToArray()
}
