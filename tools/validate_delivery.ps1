param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$MiniProgramId,
    [ValidateSet("text", "json")]
    [string]$Output = "text"
)

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

Push-Location $RepoRoot
try {
    & dart @arguments
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
