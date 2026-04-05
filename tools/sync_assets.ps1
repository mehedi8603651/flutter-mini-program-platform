param(
  [string]$MiniProgramId = 'profile_center',
  [string]$HostId = 'super_app_host'
)

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$miniProgramRoot = Join-Path $repoRoot "mini_programs\$MiniProgramId"
$hostRoot = Join-Path $repoRoot "hosts\$HostId"
$manifestSource = Join-Path $miniProgramRoot 'manifest.json'
$screensSource = Join-Path $miniProgramRoot 'stac\.build\screens'
$assetRoot = Join-Path $hostRoot "assets\mini_programs\$MiniProgramId"
$screenTarget = Join-Path $assetRoot 'screens'

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
Assert-ExistingPath -Path $hostRoot -Label 'Host root'
Assert-ExistingPath -Path $manifestSource -Label 'Manifest source'
Assert-ExistingPath -Path $screensSource -Label 'Built screens source'

Assert-ContainedPath -Path $assetRoot -Root $hostRoot -Label 'Host asset root'
Assert-ContainedPath -Path $screenTarget -Root $assetRoot -Label 'Host screen asset root'

New-Item -ItemType Directory -Force -Path $assetRoot | Out-Null
New-Item -ItemType Directory -Force -Path $screenTarget | Out-Null

Copy-Item -LiteralPath $manifestSource -Destination (Join-Path $assetRoot 'manifest.json') -Force

Get-ChildItem -LiteralPath $screenTarget -File -Filter '*.json' |
  ForEach-Object {
    Remove-Item -LiteralPath $_.FullName -Force
  }

$copiedScreens = 0
Get-ChildItem -LiteralPath $screensSource -File -Filter '*.json' |
  ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $screenTarget $_.Name) -Force
    $copiedScreens += 1
  }

if ($copiedScreens -eq 0) {
  throw "No built screen JSON files were found in $screensSource"
}

Write-Host "Synced $MiniProgramId manifest and $copiedScreens screen file(s) into hosts\$HostId\assets\mini_programs\$MiniProgramId"
