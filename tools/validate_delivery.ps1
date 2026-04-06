param(
    [string]$RepoRoot,
    [string]$MiniProgramId,
    [string]$MiniProgramRoot,
    [ValidateSet("text", "json")]
    [string]$Output = "text"
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
        throw "Unable to resolve the script root for validate_delivery.ps1."
    }

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = (Resolve-Path (Join-Path $scriptRoot "..")).Path
}

$toolPath = Join-Path $RepoRoot "packages\mini_program_tooling\bin\validate_delivery.dart"

$arguments = @(
    "run",
    $toolPath,
    "--repo-root", $RepoRoot,
    "--output", $Output
)

if ($MiniProgramId) {
    $arguments += @("--mini-program", $MiniProgramId)
}
if ($MiniProgramRoot) {
    $arguments += @("--mini-program-root", $MiniProgramRoot)
}

Push-Location $RepoRoot
try {
    & dart @arguments
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
