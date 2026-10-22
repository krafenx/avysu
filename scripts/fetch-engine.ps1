# Resolve current official releases, verify GitHub-published SHA-256 digests, then stage x64 files.
param([string]$Out = (Join-Path $PSScriptRoot "..\src-tauri\resources\engine"))
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$headers = @{ 'User-Agent' = 'Avysu-component-fetcher'; 'Accept' = 'application/vnd.github+json' }
$repos = @{
  flowseal = 'Flowseal/zapret-discord-youtube'
  zapret2 = 'bol-van/zapret2'
  windivert = 'basil00/WinDivert'
}
# This is the last known WinDivert archive without an API digest. Newer releases
# are accepted only if GitHub publishes an SHA-256 digest for the asset.
$knownDigests = @{ 'v2.2.2/WinDivert-2.2.2-A.zip' = '63CB41763BB4B20F600B6DE04E991A9C2BE73279E317D4D82F237B150C5F3F15' }
$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$outPath = [IO.Path]::GetFullPath($Out)
$resourceRoot = [IO.Path]::GetFullPath((Join-Path $project 'src-tauri\resources'))
if (-not $outPath.StartsWith(($resourceRoot.TrimEnd('\') + '\'), [StringComparison]::OrdinalIgnoreCase)) { throw "Output path must stay under $resourceRoot" }
$tmp = Join-Path $project ('.engine-tmp-' + [Guid]::NewGuid().ToString('N'))
$stage = Join-Path $tmp 'engine'
New-Item -ItemType Directory -Force -Path $tmp,$stage,(Join-Path $stage 'z1\strategies'),(Join-Path $stage 'z2\lua'),(Join-Path $stage 'z2\filter'),(Join-Path $stage 'z2\fake'),(Join-Path $stage 'lists') | Out-Null
function Find-Asset($release, $pattern, $description) {
  $asset = @($release.assets | Where-Object { $_.name -match $pattern }) | Select-Object -First 1
  if (-not $asset) { throw "No $description asset found in release $($release.tag_name)" }
  return $asset
}
try {
  $rel = @{}
  foreach ($key in $repos.Keys) { $rel[$key] = Invoke-RestMethod "https://api.github.com/repos/$($repos[$key])/releases/latest" -Headers $headers }
  $assets = @{
    flowseal = Find-Asset $rel.flowseal '^zapret-discord-youtube-.*\.zip$' 'Flowseal ZIP'
    zapret2 = Find-Asset $rel.zapret2 '^zapret2-v.*\.zip$' 'zapret2 ZIP'
    windivert = Find-Asset $rel.windivert '^WinDivert-.*-A\.zip$' 'WinDivert x64 archive'
  }
  foreach ($key in $assets.Keys) {
    $asset = $assets[$key]; $path = Join-Path $tmp "$key.zip"
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $path
    $sha = [Security.Cryptography.SHA256]::Create(); try { $actual = ([BitConverter]::ToString($sha.ComputeHash([IO.File]::ReadAllBytes($path)))).Replace('-', '') } finally { $sha.Dispose() }
    $expected = $null
    if ($asset.digest -match '^sha256:(.+)$') { $expected = $Matches[1] }
    if (-not $expected) { $keyId = "$($rel[$key].tag_name)/$($asset.name)"; if ($knownDigests.ContainsKey($keyId)) { $expected = $knownDigests[$keyId] } }
    if (-not $expected) { throw "No trusted SHA-256 digest published for $($asset.name); refusing to stage it" }
    if ($actual -ne $expected) { throw "$key archive hash mismatch: expected $expected, got $actual" }
    $assets[$key] | Add-Member -NotePropertyName verified_sha256 -NotePropertyValue $actual -Force
  }
  Expand-Archive (Join-Path $tmp 'flowseal.zip') (Join-Path $tmp 'flowseal') -Force
  Expand-Archive (Join-Path $tmp 'zapret2.zip') (Join-Path $tmp 'zapret2') -Force
  Expand-Archive (Join-Path $tmp 'windivert.zip') (Join-Path $tmp 'windivert') -Force
  $fsRoot = Get-ChildItem (Join-Path $tmp 'flowseal') -Recurse -Filter 'service.bat' | Select-Object -First 1 -ExpandProperty DirectoryName
  if (-not $fsRoot) { throw 'Flowseal archive layout is not recognized' }
  Copy-Item (Join-Path $fsRoot 'bin\*') (Join-Path $stage 'z1') -Recurse
  Get-ChildItem $fsRoot -Filter 'general*.bat' | Copy-Item -Destination (Join-Path $stage 'z1\strategies')
  Copy-Item (Join-Path $fsRoot 'lists\*') (Join-Path $stage 'lists') -Recurse
  $targets = Join-Path $fsRoot 'utils\targets.txt'; if (Test-Path $targets) { Copy-Item $targets $stage }
  $z2Root = Get-ChildItem (Join-Path $tmp 'zapret2') -Directory | Select-Object -First 1 -ExpandProperty FullName
  if (-not $z2Root) { throw 'zapret2 archive layout is not recognized' }
  $bin = Join-Path $z2Root 'binaries\windows-x86_64'
  Copy-Item (Join-Path $bin '*') (Join-Path $stage 'z2') -Recurse
  Copy-Item (Join-Path $z2Root 'lua\*.lua') (Join-Path $stage 'z2\lua')
  Copy-Item (Join-Path $z2Root 'init.d\windivert.filter.examples\*') (Join-Path $stage 'z2\filter') -Recurse
  Copy-Item (Join-Path $z2Root 'files\fake\*') (Join-Path $stage 'z2\fake') -Recurse
  Get-ChildItem (Join-Path $stage 'z1') -Filter '*.bin' | Copy-Item -Destination (Join-Path $stage 'z2\fake') -Force
  $wdRoot = Get-ChildItem (Join-Path $tmp 'windivert') -Directory | Select-Object -First 1 -ExpandProperty FullName
  $wdX64 = Join-Path $wdRoot 'x64'
  foreach ($dest in @((Join-Path $stage 'z1'),(Join-Path $stage 'z2'))) {
    Copy-Item (Join-Path $wdX64 'WinDivert.dll') $dest -Force
    Copy-Item (Join-Path $wdX64 'WinDivert64.sys') $dest -Force
  }
  foreach ($required in @('z1\winws.exe','z2\winws2.exe','z1\WinDivert.dll','z1\WinDivert64.sys','z2\WinDivert.dll','z2\WinDivert64.sys')) {
    if (-not (Test-Path (Join-Path $stage $required))) { throw "Required component missing: $required" }
  }
  $manifest = [ordered]@{
    flowseal = $rel.flowseal.tag_name; zapret2 = $rel.zapret2.tag_name; windivert = $rel.windivert.tag_name.TrimStart('v')
    archive_sha256 = [ordered]@{ flowseal=$assets.flowseal.verified_sha256.ToLower(); zapret2=$assets.zapret2.verified_sha256.ToLower(); windivert=$assets.windivert.verified_sha256.ToLower() }
  }
  [IO.File]::WriteAllText((Join-Path $stage 'version.json'), ($manifest | ConvertTo-Json -Depth 5), [Text.UTF8Encoding]::new($false))
  if (Test-Path $outPath) { Remove-Item -LiteralPath $outPath -Recurse -Force }
  New-Item -ItemType Directory -Force -Path (Split-Path $outPath -Parent) | Out-Null
  Move-Item -LiteralPath $stage -Destination $outPath
  Write-Host "Verified latest releases staged in $outPath"
} finally { if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force } }
