param(
    [string]$MiniProgramId,
    [string]$MiniProgramRoot,
    [string]$RepoRoot,
    [string]$StacCliScript,
    [switch]$SkipBuildPubGet,
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
        throw "Unable to resolve the script root for publish_mini_program.ps1."
    }

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = (Resolve-Path (Join-Path $scriptRoot "..")).Path
}

$toolPath = Join-Path $RepoRoot "packages\mini_program_tooling\bin\publish_mini_program.dart"

$arguments = @(
    "run",
    $toolPath,
    "--output", $Output
)

if ($MiniProgramRoot) { $arguments += @("--mini-program-root", $MiniProgramRoot) }
if ($RepoRoot) { $arguments += @("--repo-root", $RepoRoot) }
if ($MiniProgramId) { $arguments += @("--id", $MiniProgramId) }
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
