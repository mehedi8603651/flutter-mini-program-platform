param(
    [string]$MiniProgramId,
    [string]$MiniProgramRoot,
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$StacCliScript,
    [switch]$SkipPubGet,
    [ValidateSet("text", "json")]
    [string]$Output = "text"
)

$toolPath = Join-Path $RepoRoot "packages\mini_program_tooling\bin\build_mini_program.dart"

$arguments = @(
    "run",
    $toolPath,
    "--output", $Output
)

if ($MiniProgramRoot) { $arguments += @("--mini-program-root", $MiniProgramRoot) }
if ($RepoRoot) { $arguments += @("--repo-root", $RepoRoot) }
if ($MiniProgramId) { $arguments += @("--id", $MiniProgramId) }
if ($StacCliScript) { $arguments += @("--stac-cli-script", $StacCliScript) }
if ($SkipPubGet) { $arguments += "--skip-pub-get" }

Push-Location $RepoRoot
try {
    & dart @arguments
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
