param(
    [Parameter(Mandatory = $true)]
    [string]$MiniProgramId,

    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$Title,
    [string]$Description,
    [string]$Capabilities = "analytics,native_navigation",
    [switch]$Force,
    [ValidateSet("text", "json")]
    [string]$Output = "text"
)

$toolPath = Join-Path $RepoRoot "packages\mini_program_tooling\bin\create_mini_program.dart"

$arguments = @(
    "run",
    $toolPath,
    "--repo-root", $RepoRoot,
    "--id", $MiniProgramId,
    "--capabilities", $Capabilities,
    "--output", $Output
)

if ($Title) { $arguments += @("--title", $Title) }
if ($Description) { $arguments += @("--description", $Description) }
if ($Force) { $arguments += "--force" }

Push-Location $RepoRoot
try {
    & dart @arguments
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
