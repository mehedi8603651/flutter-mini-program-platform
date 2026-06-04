param(
  [string]$StaticOutputRoot = "$env:TEMP\mini_program_mp_engine_static_smoke",
  [switch]$SkipPackageTests,
  [switch]$SkipVsCodeTests,
  [switch]$SkipHostTests
)

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$Cli = Join-Path $RepoRoot 'packages\mini_program_tooling\bin\miniprogram.dart'
$Fixtures = @(
  'mini_programs\mp_profile_center',
  'mini_programs\mp_rewards_center'
)

function Invoke-Step {
  param(
    [string]$Name,
    [string]$WorkingDirectory,
    [string]$Command,
    [string[]]$Arguments
  )

  Write-Host ""
  Write-Host "==> $Name"
  Write-Host "    $Command $($Arguments -join ' ')"
  Push-Location $WorkingDirectory
  try {
    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
      throw "$Name failed with exit code $LASTEXITCODE."
    }
  } finally {
    Pop-Location
  }
}

function Assert-FileExists {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Expected file was not found: $Path"
  }
}

function Assert-JsonValue {
  param(
    [object]$Json,
    [string]$Path,
    [object]$Expected
  )

  $current = $Json
  foreach ($segment in $Path.Split('.')) {
    if ($null -eq $current -or -not ($current.PSObject.Properties.Name -contains $segment)) {
      throw "Expected JSON path '$Path' was missing."
    }
    $current = $current.$segment
  }
  if ($current -ne $Expected) {
    throw "Expected JSON path '$Path' to be '$Expected' but got '$current'."
  }
}

function Assert-BaseSdkDependencyClean {
  $sdkRoot = Join-Path $RepoRoot 'packages\mini_program_sdk'
  Write-Host ""
  Write-Host "==> base SDK dependency boundary"
  Push-Location $sdkRoot
  try {
    $previousErrorActionPreference = $ErrorActionPreference
    try {
      $ErrorActionPreference = 'Continue'
      $dependencyOutput = (& flutter pub deps --style=list 2>&1 | Out-String)
      $dependencyExitCode = $LASTEXITCODE
    } finally {
      $ErrorActionPreference = $previousErrorActionPreference
    }
    if ($dependencyExitCode -ne 0) {
      throw "Base SDK dependency inspection failed with exit code $dependencyExitCode."
    }
    $forbiddenPackages = @(
      'stac',
      'stac_core',
      'dio',
      'cached_network_image',
      'flutter_svg',
      'shared_preferences',
      'sqflite',
      'mini_program_legacy_stac'
    )
    foreach ($packageName in $forbiddenPackages) {
      if ($dependencyOutput -match "(?m)^\s*(?:-\s*)?$([regex]::Escape($packageName))\s") {
        throw "Base SDK dependency graph unexpectedly contains '$packageName'."
      }
    }
  } finally {
    Pop-Location
  }
}

if (-not $SkipPackageTests) {
  Invoke-Step 'contracts tests' (Join-Path $RepoRoot 'packages\mini_program_contracts') 'dart' @('test')
  Invoke-Step 'contracts analyze' (Join-Path $RepoRoot 'packages\mini_program_contracts') 'dart' @('analyze')
  Invoke-Step 'ui tests' (Join-Path $RepoRoot 'packages\mini_program_ui') 'dart' @('test')
  Invoke-Step 'ui analyze' (Join-Path $RepoRoot 'packages\mini_program_ui') 'dart' @('analyze')
  Invoke-Step 'sdk tests' (Join-Path $RepoRoot 'packages\mini_program_sdk') 'flutter' @('test')
  Invoke-Step 'sdk analyze' (Join-Path $RepoRoot 'packages\mini_program_sdk') 'flutter' @('analyze')
  Assert-BaseSdkDependencyClean
  Invoke-Step 'legacy Stac adapter tests' (Join-Path $RepoRoot 'packages\mini_program_legacy_stac') 'flutter' @('test')
  Invoke-Step 'legacy Stac adapter analyze' (Join-Path $RepoRoot 'packages\mini_program_legacy_stac') 'flutter' @('analyze')
  Invoke-Step 'tooling tests' (Join-Path $RepoRoot 'packages\mini_program_tooling') 'dart' @(
    'test',
    '--concurrency=1',
    '--timeout=2m'
  )
  Invoke-Step 'tooling analyze' (Join-Path $RepoRoot 'packages\mini_program_tooling') 'dart' @('analyze')
}

if (-not $SkipVsCodeTests) {
  Invoke-Step 'VS Code extension tests' (Join-Path $RepoRoot 'packages\mini_program_vscode') 'npm' @('test')
}

if (-not $SkipHostTests) {
  Invoke-Step 'Mp-only host widget tests' (Join-Path $RepoRoot 'hosts\mp_only_host') 'flutter' @('test')
  Invoke-Step 'super host widget tests' (Join-Path $RepoRoot 'hosts\super_app_host') 'flutter' @('test')
  Invoke-Step 'partner host widget tests' (Join-Path $RepoRoot 'hosts\partner_app_host') 'flutter' @('test')
}

if (Test-Path -LiteralPath $StaticOutputRoot) {
  Remove-Item -LiteralPath $StaticOutputRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $StaticOutputRoot | Out-Null

foreach ($fixture in $Fixtures) {
  $fixtureRoot = Join-Path $RepoRoot $fixture
  $appId = Split-Path -Leaf $fixtureRoot
  $publishRoot = Join-Path $StaticOutputRoot $appId

  Invoke-Step "build $appId" $RepoRoot 'dart' @('run', $Cli, 'build', '--mini-program-root', $fixtureRoot)
  Invoke-Step "validate $appId" $RepoRoot 'dart' @('run', $Cli, 'validate', '--mini-program-root', $fixtureRoot)
  Invoke-Step "static publish $appId" $RepoRoot 'dart' @(
    'run', $Cli, 'publish',
    '--target', 'static',
    '--output', $publishRoot,
    '--clean',
    '--mini-program-root', $fixtureRoot
  )

  Assert-FileExists (Join-Path $publishRoot "manifests\$appId\latest.json")
  Assert-FileExists (Join-Path $publishRoot "manifests\$appId\versions\1.0.0.json")
  Assert-FileExists (Join-Path $publishRoot "screens\$appId\1.0.0\$($appId)_home.json")

  $statusRaw = & dart run $Cli workflow status --workspace $fixtureRoot --json
  if ($LASTEXITCODE -ne 0) {
    throw "workflow status failed for $appId with exit code $LASTEXITCODE."
  }
  $status = $statusRaw | ConvertFrom-Json
  Assert-JsonValue $status 'miniProgram.screenFormat' 'mp'
  Assert-JsonValue $status 'miniProgram.screenSchemaVersion' 1
  Assert-JsonValue $status 'miniProgram.build.entryScreenExists' $true

  if ($appId -eq 'mp_rewards_center') {
    Assert-JsonValue $status 'miniProgram.backendUsage.usesAuthBuilder' $true
    Assert-JsonValue $status 'miniProgram.backendUsage.usesBackendBuilder' $true
    Assert-JsonValue $status 'miniProgram.backendUsage.usesPagedBackendBuilder' $true
    Assert-JsonValue $status 'miniProgram.backendUsage.usesLoadMore' $true
  }
}

Write-Host ""
Write-Host "Mp engine release verification completed."
Write-Host "Static smoke output: $StaticOutputRoot"

Write-Host ""
Write-Host "Optional non-destructive live checklist:"
Write-Host "- Firebase publish: miniprogram publish --target firebase-hosting --env my-firebase-prod --mini-program-root <fixture> --clean --json"
Write-Host "- AWS publish: miniprogram publish --target cloud --env my-aws-prod --mini-program-root <fixture>"
Write-Host "- Host import: create a protected handoff package, import it into a disposable host, and run flutter run -d chrome."
Write-Host "- Do not run destroy, delete, Firestore delete, DynamoDB delete, or cleanup commands from this script."
Write-Host "- Full commands: docs/mp_engine_cloud_e2e_guide.md"
Write-Host "- Release gates: docs/mp_engine_release_checklist.md"
