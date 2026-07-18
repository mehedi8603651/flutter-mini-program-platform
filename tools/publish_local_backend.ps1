param(
  [string]$MiniProgramId = 'mp_profile_center'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptRoot =
  if ($PSScriptRoot) {
    $PSScriptRoot
  }
  elseif ($MyInvocation.MyCommand.Path) {
    Split-Path -Parent $MyInvocation.MyCommand.Path
  }
  else {
    throw "Unable to resolve the script root for publish_local_backend.ps1."
  }

$repoRoot = (Resolve-Path (Join-Path $scriptRoot '..')).Path
$miniProgramRoot = Join-Path $repoRoot "mini_programs\$MiniProgramId"
$cliPath = Join-Path $repoRoot 'packages\mini_program_tooling\bin\miniprogram.dart'

function Assert-ExistingPath {
  param(
    [string]$Path,
    [string]$Label
  )

  if (-not (Test-Path -LiteralPath $Path)) {
    throw "$Label does not exist: $Path"
  }
}

Assert-ExistingPath -Path $miniProgramRoot -Label 'Mini-program root'
Assert-ExistingPath -Path $cliPath -Label 'Miniprogram CLI'

Push-Location $miniProgramRoot
try {
  & dart run $cliPath publish $MiniProgramId `
    --target local `
    --repo-root $repoRoot `
    --root $repoRoot `
    --mini-program-root $miniProgramRoot
  $exitCode = $LASTEXITCODE
}
finally {
  Pop-Location
}

if ($exitCode -ne 0) {
  throw "Local artifact publish failed with exit code $exitCode."
}
