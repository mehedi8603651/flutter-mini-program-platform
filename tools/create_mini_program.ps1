param(
    [Parameter(Mandatory = $true)]
    [string]$MiniProgramId,

    [string]$RepoRoot,
    [string]$OutputRoot,
    [string]$Title,
    [string]$Description,
    [string]$Capabilities = "analytics,native_navigation",
    [switch]$Force,
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
        throw "Unable to resolve the script root for create_mini_program.ps1."
    }

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = (Resolve-Path (Join-Path $scriptRoot "..")).Path
}

$toolPath = Join-Path $RepoRoot "packages\mini_program_tooling\bin\create_mini_program.dart"

$arguments = @(
    "run",
    $toolPath,
    "--id", $MiniProgramId,
    "--capabilities", $Capabilities,
    "--output", $Output
)

if ($OutputRoot) {
    $arguments += @("--output-root", $OutputRoot)
} else {
    $arguments += @("--repo-root", $RepoRoot)
}
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
