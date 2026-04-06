param(
    [Parameter(Mandatory = $true)]
    [string]$MiniProgramId,

    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$StacCliScript,
    [switch]$SkipBuildPubGet,
    [ValidateSet("text", "json")]
    [string]$Output = "text"
)

$toolPath = Join-Path $RepoRoot "packages\mini_program_tooling\bin\publish_mini_program.dart"

$arguments = @(
    "run",
    $toolPath,
    "--repo-root", $RepoRoot,
    "--id", $MiniProgramId,
    "--output", $Output
)

if ($StacCliScript) { $arguments += @("--stac-cli-script", $StacCliScript) }
if ($SkipBuildPubGet) { $arguments += "--skip-build-pub-get" }

Push-Location $RepoRoot
try {
    & dart @arguments
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
