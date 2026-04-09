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

function Resolve-MiniprogramExecutable {
    $command = Get-Command miniprogram -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    throw @'
The global `miniprogram` command was not found.

Install the published CLI:
  dart pub global activate mini_program_tooling

For repo-local contributor work:
  dart pub global activate --source path <repo-root>\packages\mini_program_tooling
'@
}

function Invoke-LegacyCreateTool {
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
}

if ($Output -eq "json") {
    Write-Warning "create_mini_program.ps1 is falling back to the legacy Dart entrypoint because -Output json is not part of the public miniprogram CLI surface."
    Invoke-LegacyCreateTool
    return
}

$miniprogramExecutable = Resolve-MiniprogramExecutable
$arguments = @("create", $MiniProgramId, "--capabilities", $Capabilities)

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
    & $miniprogramExecutable @arguments
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
