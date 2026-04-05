param(
  [string]$MiniProgramId = 'profile_center'
)

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$miniProgramRoot = Join-Path $repoRoot "mini_programs\$MiniProgramId"
$backendRoot = Join-Path $repoRoot 'backend'
$apiRoot = Join-Path $backendRoot 'api'
$manifestSource = Join-Path $miniProgramRoot 'manifest.json'
$screensSource = Join-Path $miniProgramRoot 'stac\.build\screens'

function Assert-ExistingPath {
  param(
    [string]$Path,
    [string]$Label
  )

  if (-not (Test-Path -LiteralPath $Path)) {
    throw "$Label does not exist: $Path"
  }
}

function Assert-ContainedPath {
  param(
    [string]$Path,
    [string]$Root,
    [string]$Label
  )

  $resolvedPath = [System.IO.Path]::GetFullPath($Path)
  $resolvedRoot = [System.IO.Path]::GetFullPath($Root)

  if (-not $resolvedPath.StartsWith($resolvedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "$Label must stay within $resolvedRoot, but resolved to $resolvedPath"
  }
}

Assert-ExistingPath -Path $miniProgramRoot -Label 'Mini-program root'
Assert-ExistingPath -Path $backendRoot -Label 'Backend root'
Assert-ExistingPath -Path $manifestSource -Label 'Manifest source'
Assert-ExistingPath -Path $screensSource -Label 'Built screens source'

$manifest = Get-Content -LiteralPath $manifestSource -Raw | ConvertFrom-Json
$miniProgramVersion = [string]$manifest.version

if ([string]::IsNullOrWhiteSpace($miniProgramVersion)) {
  throw "Manifest at $manifestSource does not contain a usable version."
}

$manifestTargetDir = Join-Path $apiRoot "manifests\$MiniProgramId"
$versionedManifestDir = Join-Path $manifestTargetDir 'versions'
$latestManifestTarget = Join-Path $manifestTargetDir 'latest.json'
$versionedManifestTarget = Join-Path $versionedManifestDir "$miniProgramVersion.json"
$screenTargetDir = Join-Path $apiRoot "screens\$MiniProgramId\$miniProgramVersion"

Assert-ContainedPath -Path $manifestTargetDir -Root $backendRoot -Label 'Manifest target directory'
Assert-ContainedPath -Path $screenTargetDir -Root $backendRoot -Label 'Screen target directory'

New-Item -ItemType Directory -Force -Path $manifestTargetDir | Out-Null
New-Item -ItemType Directory -Force -Path $versionedManifestDir | Out-Null
New-Item -ItemType Directory -Force -Path $screenTargetDir | Out-Null

Copy-Item -LiteralPath $manifestSource -Destination $latestManifestTarget -Force
Copy-Item -LiteralPath $manifestSource -Destination $versionedManifestTarget -Force

Get-ChildItem -LiteralPath $screenTargetDir -File -Filter '*.json' |
  ForEach-Object {
    Remove-Item -LiteralPath $_.FullName -Force
  }

$copiedScreens = 0
Get-ChildItem -LiteralPath $screensSource -File -Filter '*.json' |
  ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $screenTargetDir $_.Name) -Force
    $copiedScreens += 1
  }

if ($copiedScreens -eq 0) {
  throw "No built screen JSON files were found in $screensSource"
}

Write-Host "Published $MiniProgramId v$miniProgramVersion to backend\\api with $copiedScreens screen file(s)."
