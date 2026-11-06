function Get-BookSiftReleaseAssets {
  param(
    [Parameter(Mandatory)][string]$DistDir,
    [Parameter(Mandatory)][string]$Version,
    [Parameter(Mandatory)][int]$SeedPackVersion
  )

  $manifestPath = Join-Path $DistDir 'version.json'
  $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json -AsHashtable
  if ($manifest.app.version -ne $Version) { throw 'version.json version mismatch' }
  $platforms = [ordered]@{
    "BookSift-android-v$Version.apk" = 'apk'
    "BookSift-windows-x64-v$Version.zip" = 'windows'
    "BookSift-linux-x64-v$Version.tar.gz" = 'linux'
    "BookSift-ios-v$Version.ipa" = 'ios'
    "BookSift-macos-universal-v$Version.zip" = 'macos'
  }
  $extras = @("seed_pack_lite_v$SeedPackVersion.zip", "classifier-source-v$Version.zip")
  $names = @($platforms.Keys) + $extras
  $assets = [System.Collections.Generic.List[string]]::new()
  foreach ($name in $names) {
    $path = Join-Path $DistDir $name
    if (Test-Path -LiteralPath $path -PathType Leaf) {
      $assets.Add((Resolve-Path -LiteralPath $path).Path)
      $actual = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
      $expected = if ($platforms.Contains($name)) {
        $manifest.app["$($platforms[$name])_sha256"]
      } else {
        $manifest.assets[$name].sha256
      }
      if ($expected -ne $actual) { throw "Manifest checksum mismatch: $name" }
    }
  }
  $assets.Add((Resolve-Path -LiteralPath $manifestPath).Path)
  return $assets.ToArray()
}
